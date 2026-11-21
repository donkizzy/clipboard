import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Clipboard

@Suite("HistoryDatabase")
struct HistoryDatabaseTests {
    private let paths: AppPaths
    private let database: HistoryDatabase

    init() throws {
        paths = try TestSupport.temporaryPaths()
        database = HistoryDatabase(container: HistoryStore.makeInMemoryContainer(), images: ImageStore(paths: paths))
    }

    private func titles() async throws -> [String] {
        try await database.snapshots().map(\.title)
    }

    private func imageClip(gray: CGFloat, at date: Date = .now) throws -> PreparedClip {
        let data = TestSupport.pngData(gray: gray)
        return try #require(CaptureProcessor.prepare(.image(.init(data: data, typeIdentifier: UTType.png.identifier)), source: nil, now: date))
    }

    // MARK: Dedupe

    @Test("Snapshots are newest first")
    func ordering() async throws {
        let start = Date(timeIntervalSince1970: 1_000)
        try await database.ingest(TestSupport.textClip("one", at: start), retentionLimit: nil)
        try await database.ingest(TestSupport.textClip("two", at: start + 10), retentionLimit: nil)
        #expect(try await titles() == ["two", "one"])
    }

    @Test("Copying the same content again moves it to the top instead of duplicating")
    func dedupe() async throws {
        let start = Date(timeIntervalSince1970: 1_000)
        try await database.ingest(TestSupport.textClip("repeat", at: start), retentionLimit: nil)
        try await database.ingest(TestSupport.textClip("other", at: start + 10), retentionLimit: nil)

        let notes = SourceApp(name: "Notes", bundleID: "com.apple.Notes")
        let result = try await database.ingest(TestSupport.textClip("repeat", at: start + 20, source: notes), retentionLimit: nil)

        guard case .bumped = result else {
            Issue.record("Expected a bump, got \(result)")
            return
        }
        let snapshots = try await database.snapshots()
        #expect(snapshots.map(\.title) == ["repeat", "other"])
        #expect(snapshots[0].createdAt == start + 20)
        #expect(snapshots[0].source?.name == "Notes")
    }

    @Test("A duplicate image writes no new files")
    func imageDedupe() async throws {
        try await database.ingest(imageClip(gray: 0.2), retentionLimit: nil)
        try await database.ingest(imageClip(gray: 0.2), retentionLimit: nil)
        #expect(try await database.snapshots().count == 1)
        #expect(TestSupport.files(in: paths.imagesDirectory).count == 1)
        #expect(TestSupport.files(in: paths.thumbnailsDirectory).count == 1)
    }

    // MARK: Retention

    @Test("Retention keeps the newest N unpinned items")
    func retention() async throws {
        let start = Date(timeIntervalSince1970: 1_000)
        for index in 0..<5 {
            try await database.ingest(TestSupport.textClip("item \(index)", at: start + Double(index)), retentionLimit: 3)
        }
        #expect(try await titles() == ["item 4", "item 3", "item 2"])
    }

    @Test("Pinned items never expire and don't count towards the limit")
    func retentionWithPinned() async throws {
        let start = Date(timeIntervalSince1970: 1_000)
        try await database.ingest(TestSupport.textClip("pinned old", at: start), retentionLimit: nil)
        let pinnedID = try #require(try await database.snapshots().first?.id)
        try await database.setPinned(true, for: pinnedID)

        for index in 1...4 {
            try await database.ingest(TestSupport.textClip("item \(index)", at: start + Double(index)), retentionLimit: 2)
        }
        #expect(try await titles() == ["item 4", "item 3", "pinned old"])
    }

    @Test("Unlimited retention keeps everything")
    func unlimited() async throws {
        for index in 0..<20 {
            try await database.ingest(TestSupport.textClip("item \(index)"), retentionLimit: nil)
        }
        #expect(try await database.snapshots().count == 20)
    }

    @Test("Expired and deleted images take their files with them")
    func imageFilesRemoved() async throws {
        let start = Date(timeIntervalSince1970: 1_000)
        try await database.ingest(imageClip(gray: 0.1, at: start), retentionLimit: 1)
        try await database.ingest(imageClip(gray: 0.9, at: start + 1), retentionLimit: 1)
        #expect(TestSupport.files(in: paths.imagesDirectory).count == 1)

        let remaining = try #require(try await database.snapshots().first)
        try await database.delete(remaining.id)
        #expect(TestSupport.files(in: paths.imagesDirectory).isEmpty)
        #expect(TestSupport.files(in: paths.thumbnailsDirectory).isEmpty)
    }

    @Test("Clearing history keeps pinned items")
    func clear() async throws {
        try await database.ingest(TestSupport.textClip("keep"), retentionLimit: nil)
        try await database.setPinned(true, for: try #require(try await database.snapshots().first?.id))
        try await database.ingest(TestSupport.textClip("drop"), retentionLimit: nil)
        try await database.clear(keepPinned: true)
        #expect(try await titles() == ["keep"])
    }

    @Test("Orphaned files are cleaned up")
    func orphans() async throws {
        try await database.ingest(imageClip(gray: 0.4), retentionLimit: nil)
        try Data([0]).write(to: paths.imagesDirectory.appending(path: "stray.png"))
        #expect(try await database.removeOrphanedFiles() == 1)
        #expect(TestSupport.files(in: paths.imagesDirectory).count == 1)
    }

    @Test("Favicons are deleted with the last link that uses them")
    func favicons() async throws {
        let first = try #require(CaptureProcessor.prepare(.link(URL(string: "https://github.com/a")!), source: nil))
        let second = try #require(CaptureProcessor.prepare(.link(URL(string: "https://github.com/b")!), source: nil))
        try await database.ingest(first, retentionLimit: nil)
        try await database.ingest(second, retentionLimit: nil)
        try Data([1]).write(to: paths.faviconsDirectory.appending(path: "gh.png"))
        try await database.updateLinkMetadata(for: first.id, title: nil, faviconFileName: "gh.png")
        try await database.updateLinkMetadata(for: second.id, title: nil, faviconFileName: "gh.png")

        try await database.delete(first.id)
        #expect(TestSupport.files(in: paths.faviconsDirectory) == ["gh.png"], "still used by the second link")
        try await database.clear(keepPinned: true)
        #expect(TestSupport.files(in: paths.faviconsDirectory).isEmpty)
    }

    // MARK: Payloads

    @Test("Long text keeps a preview in the row and the full text for paste")
    func longText() async throws {
        let long = String(repeating: "x", count: ClipContent.Text.previewLimit + 500)
        try await database.ingest(TestSupport.textClip(long), retentionLimit: nil)
        let snapshot = try #require(try await database.snapshots().first)
        guard case .text(let text) = snapshot.content else {
            Issue.record("Expected text")
            return
        }
        #expect(text.preview.count == ClipContent.Text.previewLimit)
        #expect(try await database.payload(for: snapshot.id) == .text(long))
    }

    @Test("Image payloads point at the saved original")
    func imagePayload() async throws {
        try await database.ingest(imageClip(gray: 0.3), retentionLimit: nil)
        let snapshot = try #require(try await database.snapshots().first)
        guard case .image(let url)? = try await database.payload(for: snapshot.id) else {
            Issue.record("Expected an image payload")
            return
        }
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }
}

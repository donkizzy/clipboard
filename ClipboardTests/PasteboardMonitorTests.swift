import AppKit
import Foundation
import os
import Testing
@testable import Clipboard

/// End-to-end capture against a private, uniquely named pasteboard, so the
/// tests never read or clobber the user's real clipboard.
@Suite("PasteboardMonitor")
struct PasteboardMonitorTests {
    private final class Collector: Sendable {
        private let clips = OSAllocatedUnfairLock<[PreparedClip]>(initialState: [])
        func append(_ clip: PreparedClip) { clips.withLock { $0.append(clip) } }
        var all: [PreparedClip] { clips.withLock { $0 } }
    }

    private let name = NSPasteboard.Name("ClipboardTests-\(UUID().uuidString)")
    private let collector = Collector()
    private let ownWrites = OwnPasteboardWrites()
    private let frontmost = FrontmostAppTracker.State(current: TestSupport.safari)

    private func makeMonitor(policy: CapturePolicy = CapturePolicy()) -> PasteboardMonitor {
        let collector = collector
        return PasteboardMonitor(pasteboardName: name, frontmostApp: frontmost, ownWrites: ownWrites, policy: policy) {
            collector.append($0)
        }
    }

    private var pasteboard: NSPasteboard { NSPasteboard(name: name) }

    private func write(_ string: String, extraTypes: [String] = []) {
        let pasteboard = pasteboard
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        for type in extraTypes {
            pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType(type))
        }
    }

    @Test("Captures text with the frontmost app as source")
    func capturesText() async {
        let monitor = makeMonitor()
        write("hello from the test")
        await monitor.poll()
        #expect(collector.all.map(\.title) == ["hello from the test"])
        #expect(collector.all.first?.source?.name == "Safari")
    }

    @Test("Only captures when changeCount moves")
    func pollsChangeCount() async {
        let monitor = makeMonitor()
        write("once")
        await monitor.poll()
        await monitor.poll()
        #expect(collector.all.count == 1)
        write("twice")
        await monitor.poll()
        #expect(collector.all.count == 2)
    }

    @Test("Skips concealed items without reading them")
    func skipsConcealed() async {
        let monitor = makeMonitor()
        write("hunter2", extraTypes: [PrivacyFilter.concealedType])
        await monitor.poll()
        #expect(collector.all.isEmpty)
    }

    @Test("Skips items from ignored apps")
    func skipsIgnoredApps() async {
        frontmost.update(SourceApp(name: "1Password", bundleID: "com.1password.1password"))
        let monitor = makeMonitor()
        write("secret")
        await monitor.poll()
        #expect(collector.all.isEmpty)
    }

    @Test("A copy in an ignored app is skipped even after a quick switch away")
    func skipsAfterQuickSwitch() async {
        let monitor = makeMonitor()
        await monitor.poll() // consume the initial state
        frontmost.update(SourceApp(name: "Keychain Access", bundleID: "com.apple.keychainaccess"))
        write("p4ssw0rd")
        frontmost.update(TestSupport.safari) // ⌘Tab before the next poll
        await monitor.poll()
        #expect(collector.all.allSatisfy { $0.title != "p4ssw0rd" })
    }

    @Test("Ignored apps are matched by the source marker even when the app can't be resolved")
    func skipsByRawMarker() async {
        var policy = CapturePolicy()
        policy.ignoredBundleIDs.insert("com.example.vault-helper")
        let monitor = makeMonitor(policy: policy)
        let pasteboard = pasteboard
        pasteboard.clearContents()
        pasteboard.setString("secret", forType: .string)
        pasteboard.setString("com.example.vault-helper", forType: PasteboardReader.sourceType)
        await monitor.poll()
        #expect(collector.all.isEmpty)
    }

    @Test("Our own writes are recognised by the source marker (e.g. after a relaunch)")
    func skipsOwnMarker() async throws {
        let monitor = makeMonitor()
        let pasteboard = pasteboard
        pasteboard.clearContents()
        pasteboard.setString("pasted earlier", forType: .string)
        pasteboard.setString(try #require(Bundle.main.bundleIdentifier), forType: PasteboardReader.sourceType)
        await monitor.poll()
        #expect(collector.all.isEmpty)
    }

    @Test("Ignores changes the app made itself")
    func ignoresOwnWrites() async {
        let monitor = makeMonitor()
        write("ours")
        ownWrites.register(pasteboard.changeCount)
        await monitor.poll()
        #expect(collector.all.isEmpty)
    }

    @Test("Pausing stops capture until resumed")
    func pause() async {
        let monitor = makeMonitor(policy: CapturePolicy(isPaused: true))
        write("while paused")
        await monitor.poll()
        #expect(collector.all.isEmpty)

        await monitor.update(policy: CapturePolicy())
        write("after resume")
        await monitor.poll()
        #expect(collector.all.map(\.title) == ["after resume"])
    }

    @Test("Captures PNG images")
    func capturesImage() async {
        let monitor = makeMonitor()
        let pasteboard = pasteboard
        pasteboard.clearContents()
        pasteboard.setData(TestSupport.pngData(width: 20, height: 10), forType: .png)
        await monitor.poll()
        #expect(collector.all.first?.kind == .image)
        #expect(collector.all.first?.image?.pixelWidth == 20)
    }

    @Test("Captures file URLs as files")
    func capturesFiles() async throws {
        let paths = try TestSupport.temporaryPaths()
        let file = paths.root.appending(path: "notes.txt")
        try Data("hi".utf8).write(to: file)

        let monitor = makeMonitor()
        let pasteboard = pasteboard
        pasteboard.clearContents()
        pasteboard.writeObjects([file as NSURL])
        await monitor.poll()
        #expect(collector.all.first?.kind == .doc)
        #expect(collector.all.first?.title == "notes.txt")
    }
}

@MainActor
@Suite("HistoryStore")
struct HistoryStoreTests {
    private func makeStore(limit: Int? = nil) throws -> HistoryStore {
        HistoryStore(
            container: HistoryStore.makeInMemoryContainer(),
            images: ImageStore(paths: try TestSupport.temporaryPaths()),
            retentionLimit: limit
        )
    }

    @Test("Ingested clips appear in snapshots, newest first")
    func ingest() async throws {
        let store = try makeStore()
        let start = Date(timeIntervalSince1970: 1_000)
        store.ingest(TestSupport.textClip("first", at: start))
        store.ingest(TestSupport.textClip("second", at: start + 1))
        await store.waitUntilIdle()
        #expect(store.snapshots.map(\.title) == ["second", "first"])
    }

    @Test("Pin and delete apply immediately and persist")
    func optimistic() async throws {
        let store = try makeStore()
        store.ingest(TestSupport.textClip("a"))
        store.ingest(TestSupport.textClip("b"))
        await store.waitUntilIdle()
        let target = try #require(store.snapshots.first)

        store.setPinned(true, for: target.id)
        #expect(store.snapshots.first?.isPinned == true) // before the write lands
        store.delete(store.snapshots[1].id)
        #expect(store.snapshots.count == 1)

        await store.waitUntilIdle()
        #expect(store.snapshots.map(\.title) == [target.title])
        #expect(store.snapshots.first?.isPinned == true)
    }

    @Test("Changing the limit applies retention")
    func retentionChange() async throws {
        let store = try makeStore()
        for index in 0..<6 {
            store.ingest(TestSupport.textClip("item \(index)", at: Date(timeIntervalSince1970: Double(index))))
        }
        await store.waitUntilIdle()
        store.retentionLimit = 2
        store.applyRetention()
        await store.waitUntilIdle()
        #expect(store.snapshots.map(\.title) == ["item 5", "item 4"])
    }
}

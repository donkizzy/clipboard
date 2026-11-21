import Foundation
import Testing
@testable import Clipboard

@Suite("LinkPreviewPolicy")
struct LinkPreviewPolicyTests {
    @Test("Public web links may be fetched", arguments: [
        "https://framer.com/motion", "http://example.org/page", "https://8.8.8.8/",
    ])
    func allowed(string: String) {
        #expect(LinkPreviewPolicy.allowsFetching(URL(string: string)!))
    }

    @Test("Local and private-network links are never fetched", arguments: [
        "http://localhost:3000", "https://router.local/admin", "http://intranet/wiki",
        "http://10.0.0.5/", "http://192.168.1.1", "http://172.20.3.4", "http://127.0.0.1:8080",
        "http://169.254.1.1", "http://[::1]:8000/", "https://build.internal/job/1", "ftp://example.com",
    ])
    func blocked(string: String) {
        #expect(!LinkPreviewPolicy.allowsFetching(URL(string: string)!))
    }
}

@Suite("Link metadata")
struct LinkMetadataTests {
    @Test("Fetched titles and favicons are stored and shown")
    func update() async throws {
        let paths = try TestSupport.temporaryPaths()
        let database = HistoryDatabase(container: HistoryStore.makeInMemoryContainer(), images: ImageStore(paths: paths))
        let clip = try #require(CaptureProcessor.prepare(.link(URL(string: "https://framer.com/motion")!), source: nil))
        try await database.ingest(clip, retentionLimit: nil)

        var snapshot = try #require(try await database.snapshots().first)
        #expect(snapshot.displayTitle == "framer.com") // the domain until the title arrives

        try await database.updateLinkMetadata(for: clip.id, title: "Framer Motion", faviconFileName: "abc.png")
        snapshot = try #require(try await database.snapshots().first)
        #expect(snapshot.displayTitle == "Framer Motion")
        guard case .link(let link) = snapshot.content else {
            Issue.record("Expected a link")
            return
        }
        #expect(link.faviconURL == paths.faviconsDirectory.appending(path: "abc.png"))
        #expect(snapshot.searchKey.contains("framer motion"))
    }
}

@MainActor
@Suite("Preferences")
struct PreferencesTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "PreferencesTests-\(UUID().uuidString)")!
    }

    @Test("Defaults match the spec")
    func defaults() {
        let preferences = Preferences(defaults: freshDefaults())
        #expect(preferences.appearance == .system)
        #expect(preferences.historyLimit == 500)
        #expect(preferences.ignoresConcealed)
        #expect(preferences.fetchesLinkPreviews)
        #expect(!preferences.pinnedOnTop)
        #expect(preferences.ignoredBundleIDs == CapturePolicy.defaultIgnoredBundleIDs)
    }

    @Test("Changes persist, including unlimited history")
    func persistence() {
        let defaults = freshDefaults()
        let preferences = Preferences(defaults: defaults)
        preferences.historyLimit = nil
        preferences.appearance = .light
        preferences.ignoredBundleIDs = ["com.example.app"]

        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.historyLimit == nil)
        #expect(reloaded.appearance == .light)
        #expect(reloaded.ignoredBundleIDs == ["com.example.app"])
    }

    @Test("Pausing is reflected in the capture policy but never persisted")
    func pause() {
        let defaults = freshDefaults()
        let preferences = Preferences(defaults: defaults)
        preferences.isCapturePaused = true
        #expect(preferences.capturePolicy.isPaused)
        #expect(!Preferences(defaults: defaults).isCapturePaused)
    }
}

@MainActor
@Suite("InMemoryClipStore")
struct InMemoryClipStoreTests {
    @Test("Clearing keeps pinned items")
    func clear() {
        let store = InMemoryClipStore(snapshots: DemoSeed.snapshots())
        store.clear(keepPinned: true)
        #expect(store.snapshots.map(\.title) == ["Ship v2.3 by Friday", "debounce()"])
        store.clear(keepPinned: false)
        #expect(store.snapshots.isEmpty)
    }
}

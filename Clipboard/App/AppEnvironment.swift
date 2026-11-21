import AppKit

/// Composition root: builds the object graph once at launch.
@MainActor
final class AppEnvironment {
    let preferences: Preferences
    let store: any ClipStore
    let panelModel: PanelModel
    let panelController: PanelController

    /// `nil` in demo mode, which never records the real clipboard.
    private(set) var capture: CaptureService?

    init(isDemo: Bool = DemoSeed.isEnabled) {
        preferences = Preferences()

        if isDemo {
            // Deterministic sample data for screenshots and UI tests; the
            // real history on disk is left untouched.
            store = InMemoryClipStore(snapshots: DemoSeed.snapshots())
        } else {
            let paths = AppPaths.standard
            let history = HistoryStore(
                container: HistoryStore.makeContainer(paths: paths),
                images: ImageStore(paths: paths),
                retentionLimit: preferences.historyLimit
            )
            store = history
            capture = CaptureService(store: history, preferences: preferences)
        }

        panelModel = PanelModel(store: store, preferences: preferences)
        panelController = PanelController(model: panelModel)
    }

    func start() {
        capture?.start()
    }
}

/// Wires the pasteboard monitor to the history store and keeps its policy
/// and the retention limit in sync with Preferences.
@MainActor
final class CaptureService {
    let ownWrites = OwnPasteboardWrites()
    private let store: HistoryStore
    private let preferences: Preferences
    private let frontmostApp = FrontmostAppTracker()
    private let monitor: PasteboardMonitor

    init(store: HistoryStore, preferences: Preferences) {
        self.store = store
        self.preferences = preferences
        monitor = PasteboardMonitor(
            frontmostApp: frontmostApp.current,
            ownWrites: ownWrites,
            policy: preferences.capturePolicy
        ) { [weak store] clip in
            await store?.ingest(clip)
        }
    }

    func start() {
        frontmostApp.start()
        let monitor = monitor
        Task { await monitor.start() }

        observe(self, { [preferences] in preferences.capturePolicy }) { service, policy in
            let monitor = service.monitor
            Task { await monitor.update(policy: policy) }
        }
        observe(self, { [preferences] in preferences.historyLimit }) { service, limit in
            service.store.retentionLimit = limit
            service.store.applyRetention()
        }
    }
}

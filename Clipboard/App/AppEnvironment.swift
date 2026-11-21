import AppKit
import KeyboardShortcuts

/// Composition root: builds the object graph once at launch.
@MainActor
final class AppEnvironment {
    let preferences: Preferences
    let store: any ClipStore
    let panelModel: PanelModel
    let panelController: PanelController
    let onboarding = AccessibilityOnboarding()
    private let isDemo: Bool
    private var settingsWindow: SettingsWindowController?

    /// False in demo mode, which never records the real clipboard.
    var capturesClipboard: Bool { capture != nil }

    /// `nil` in demo mode, which never records the real clipboard.
    private(set) var capture: CaptureService?

    init(isDemo: Bool = DemoSeed.isEnabled) {
        self.isDemo = isDemo
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
            let preferences = preferences
            history.linkMetadata = LinkMetadataService(images: ImageStore(paths: paths)) {
                preferences.fetchesLinkPreviews
            }
        }

        panelModel = PanelModel(store: store, preferences: preferences)
        panelController = PanelController(
            model: panelModel,
            pasteService: PasteService(ownWrites: capture?.ownWrites),
            onboarding: onboarding
        )
        panelController.openSettings = { [weak self] in self?.showSettings() }
    }

    func showSettings(tab: SettingsTab? = nil) {
        panelController.hide()
        let settings = settingsWindow ?? SettingsWindowController(
            preferences: preferences,
            actions: SettingsActions(
                showAccessibilityOnboarding: { [weak self] in self?.onboarding.present() },
                clearHistory: { [weak self] in self?.confirmClearHistory() }
            )
        )
        settingsWindow = settings
        settings.show(tab: tab)
    }

    /// Asks before clearing; pinned items are always kept.
    func confirmClearHistory() {
        panelController.hide()
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "All items except pinned ones will be removed. This can't be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.clear(keepPinned: true)
        ImageCache.shared.removeAll()
    }

    func start() {
        capture?.start()
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak panelController] in
            panelController?.toggle()
        }
        // Demo mode opens straight into the panel for screenshots and UI tests;
        // normally it waits for the hotkey or the menu bar.
        if isDemo { panelController.show() }
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

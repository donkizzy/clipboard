import Foundation
import Observation

/// A transient confirmation shown at the bottom of the panel.
struct Toast: Identifiable, Equatable, Sendable {
    enum Style: Sendable {
        case copied
        case pasted
        case deleted
        case failed
    }

    let id = UUID()
    let message: String
    let style: Style

    static let copied = Toast(message: "Copied to clipboard", style: .copied)
    static let deleted = Toast(message: "Deleted", style: .deleted)
    static let failed = Toast(message: "Couldn't copy this item", style: .failed)

    /// "Pasted → Notes", naming the app when known.
    static func pasted(into appName: String?) -> Toast {
        Toast(message: "Pasted → \(appName ?? "frontmost app")", style: .pasted)
    }
}

/// Performs copy and paste for the panel. Implemented by `PanelController`,
/// which owns the AppKit side (pasteboard, previous app, window).
@MainActor
protocol PanelActionHandling: AnyObject {
    func copy(_ clip: ClipSnapshot)
    func paste(_ clip: ClipSnapshot)
}

/// State and intents for the floating panel: query, filter, selection,
/// Quick Look and toasts. UI-framework agnostic, so it is unit-testable;
/// AppKit concerns (window, focus, key events) live in `PanelController`.
@MainActor
@Observable
final class PanelModel {
    // MARK: Dependencies

    @ObservationIgnored let store: any ClipStore
    @ObservationIgnored let preferences: Preferences

    // MARK: State

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            refresh(resettingSelection: true)
        }
    }

    private(set) var filter: HistoryFilter = .all

    /// Items matching the current query and filter, in display order.
    private(set) var visible: [ClipSnapshot] = []

    /// Per-tab counts across the whole history (independent of the search text).
    private(set) var counts: [HistoryFilter: Int] = [:]

    /// Index into `visible`. Derived from `selectedID` after every refresh,
    /// so the same item stays selected when the list reorders or grows.
    private(set) var selectedIndex = 0
    @ObservationIgnored private var selectedID: ClipSnapshot.ID?
    private(set) var isPreviewOpen = false
    private(set) var toast: Toast?

    /// Drives the open animation; flipped by `PanelController`.
    private(set) var isPresented = false

    /// Reference time for relative timestamps; ticks every 30s while open.
    private(set) var now = Date.now

    @ObservationIgnored weak var actionHandler: (any PanelActionHandling)?

    /// The global shortcut, shown in the search bar chip.
    var hotkeyLabel: String? = "⌘⇧V"

    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?

    init(store: any ClipStore, preferences: Preferences) {
        self.store = store
        self.preferences = preferences
        observeStore()
    }

    // MARK: Derived

    var selected: ClipSnapshot? {
        visible.indices.contains(selectedIndex) ? visible[selectedIndex] : nil
    }

    var layout: PanelLayout { preferences.layout }

    var historyQuery: HistoryQuery {
        HistoryQuery(text: query, filter: filter, pinnedFirst: preferences.pinnedOnTop)
    }

    // MARK: Lifecycle

    /// Every open starts fresh: empty search, newest item selected.
    /// The filter and layout persist between opens.
    func panelWillShow() {
        now = .now
        query = ""
        isPreviewOpen = false
        toast = nil
        refresh(resettingSelection: true)
        startClock()
    }

    func setPresented(_ presented: Bool) {
        isPresented = presented
    }

    func panelDidHide() {
        isPresented = false
        isPreviewOpen = false
        clockTask?.cancel()
        clockTask = nil
    }

    // MARK: Intents

    func setFilter(_ newFilter: HistoryFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        isPreviewOpen = false
        refresh(resettingSelection: true)
    }

    func select(index: Int) {
        guard !visible.isEmpty else { return }
        setSelection(index)
    }

    func select(_ id: ClipSnapshot.ID) {
        guard let index = visible.firstIndex(where: { $0.id == id }) else { return }
        setSelection(index)
        isPreviewOpen = false
    }

    func moveSelection(by delta: Int) {
        select(index: selectedIndex + delta)
    }

    func openPreview(_ id: ClipSnapshot.ID? = nil) {
        if let id { select(id) }
        guard selected != nil else { return }
        isPreviewOpen = true
    }

    func closePreview() {
        isPreviewOpen = false
    }

    func togglePreview() {
        isPreviewOpen ? closePreview() : openPreview()
    }

    func togglePin(_ id: ClipSnapshot.ID? = nil) {
        guard let clip = clip(for: id) else { return }
        store.setPinned(!clip.isPinned, for: clip.id)
        refresh()
    }

    func delete(_ id: ClipSnapshot.ID? = nil) {
        guard let clip = clip(for: id) else { return }
        store.delete(clip.id)
        refresh()
        show(.deleted)
    }

    /// ↵: copies the selected item to the pasteboard.
    func copySelected() {
        guard let selected else { return }
        actionHandler?.copy(selected)
    }

    /// ⌘↵: pastes the selected item into the app that was frontmost.
    func pasteSelected() {
        guard let selected else { return }
        actionHandler?.paste(selected)
    }

    /// Esc: close the preview, else clear the search. Returns `false` when
    /// there was nothing left to back out of, meaning the panel should close.
    func handleEscape() -> Bool {
        if isPreviewOpen {
            closePreview()
            return true
        }
        if !query.isEmpty {
            query = ""
            return true
        }
        return false
    }


    func toggleLayout() {
        preferences.layout = preferences.layout.toggled
    }

    /// Flips between dark and light from whatever is currently showing,
    /// and saves the choice (leaving "System" behind, as in the design).
    func toggleAppearance(currentlyDark: Bool) {
        preferences.appearance = currentlyDark ? .light : .dark
    }

    func show(_ toast: Toast) {
        self.toast = toast
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: Metrics.Toast.visibleDuration)
            guard !Task.isCancelled, self?.toast?.id == toast.id else { return }
            self?.toast = nil
        }
    }

    // MARK: Private

    private func clip(for id: ClipSnapshot.ID?) -> ClipSnapshot? {
        guard let id else { return selected }
        return visible.first { $0.id == id }
    }

    /// Recomputes `visible` and `counts` from the store, keeping the
    /// selected item selected. If it's gone, the selection stays at the same
    /// position (i.e. moves to the next item), clamped to the end.
    private func refresh(resettingSelection: Bool = false) {
        let all = store.snapshots
        visible = historyQuery.apply(to: all)
        counts = HistoryQuery.counts(for: all)

        if resettingSelection {
            setSelection(0)
        } else if let selectedID, let index = visible.firstIndex(where: { $0.id == selectedID }) {
            selectedIndex = index
        } else {
            setSelection(selectedIndex)
        }
        if visible.isEmpty { isPreviewOpen = false }
    }

    private func setSelection(_ index: Int) {
        guard !visible.isEmpty else {
            selectedIndex = 0
            selectedID = nil
            return
        }
        selectedIndex = min(max(index, 0), visible.count - 1)
        selectedID = visible[selectedIndex].id
    }

    /// Re-runs `refresh()` whenever the store's snapshots or the
    /// pinned-on-top preference change.
    private func observeStore() {
        withObservationTracking {
            _ = store.snapshots
            _ = preferences.pinnedOnTop
        } onChange: { [weak self] in
            // `onChange` fires before the new value is set; hop to the next turn.
            Task { @MainActor [weak self] in
                self?.observeStore()
            }
        }
        refresh()
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                self?.now = .now
            }
        }
    }
}

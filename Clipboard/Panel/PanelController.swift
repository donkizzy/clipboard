import AppKit
import SwiftUI

/// Window geometry around the visible panel.
enum PanelGeometry {
    /// Room for the panel's drop shadow (0 32 80 −12 extends ~36pt above,
    /// ~68pt to the sides and ~100pt below the panel).
    static let margins = EdgeInsets(top: 40, leading: 72, bottom: 104, trailing: 72)

    /// Tallest the panel gets (list layout at its 340pt cap).
    static let maxPanelHeight: CGFloat = 500

    /// Approximate panel height in the row layout, used to centre it on screen.
    static let typicalPanelHeight: CGFloat = 366

    /// Minimum gap between the panel and the screen edges.
    static let screenInset: CGFloat = 16
}

/// Shows, hides and positions the floating panel. Owns the window, so the
/// SwiftUI hierarchy is built once and reused: opening is just a re-position
/// and fade, which keeps open latency well under the 100ms budget.
@MainActor
final class PanelController {
    private let model: PanelModel
    private let pasteService: PasteService
    private let onboarding: AccessibilityOnboarding
    private let toastWindow = ToastWindow()
    private let searchFocus = SearchFocus()
    private let panel = FloatingPanel()
    private var resignObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var dismissTask: Task<Void, Never>?

    /// Opens the Settings window (⌘, in the panel).
    var openSettings: (() -> Void)?

    /// The app that was frontmost when the panel opened; paste goes back here.
    private(set) var previousApp: NSRunningApplication?

    var isVisible: Bool { panel.isVisible }

    /// Long enough to read "Copied", short enough not to feel sluggish.
    static let dismissDelayAfterCopy: Duration = .milliseconds(600)

    init(model: PanelModel, pasteService: PasteService, onboarding: AccessibilityOnboarding) {
        self.model = model
        self.pasteService = pasteService
        self.onboarding = onboarding

        let content = PanelWindowContent(model: model, searchFocus: searchFocus) { [weak panel] rect in
            panel?.panelRect = rect
        }
        let hostingView = NSHostingView(rootView: content)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onClickOutsidePanel = { [weak self] in self?.hide() }
        model.actionHandler = self

        // A local monitor sees key events before the field editor and before
        // key-equivalent handling, so the panel's shortcuts always win.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKeyDown(event) ?? false }
            return handled ? nil : event
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    /// Renders the panel once, invisibly, at launch. The first real open
    /// otherwise pays for the window's backing store and SwiftUI's first
    /// full render (~50–90ms); afterwards every open costs ~11ms.
    func prewarm() {
        guard !isVisible else { return }
        position(on: screenUnderMouse())
        model.panelWillShow()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        CATransaction.flush()
        panel.orderOut(nil)
        panel.alphaValue = 1
        model.panelDidHide()
    }

    func show() {
        guard !isVisible else { return }
        dismissTask?.cancel()
        rememberFrontmostApp()
        position(on: screenUnderMouse())
        model.hotkeyLabel = HotkeyLabel.current
        model.panelWillShow()

        panel.orderFrontRegardless()
        panel.makeKey()
        // Make sure the field exists (first open) before focusing it, so the
        // first keystroke can never land on the results.
        panel.contentView?.layoutSubtreeIfNeeded()
        searchFocus.focus()
        if !searchFocus.isFocused {
            DispatchQueue.main.async { [searchFocus] in searchFocus.focus() }
        }

        withAnimation(Motion.panelOpen) {
            model.setPresented(true)
        }
    }

    func hide() {
        dismissTask?.cancel()
        guard isVisible else { return }
        panel.orderOut(nil)
        model.panelDidHide()
    }

    /// Hides after `delay`, unless the panel is hidden or reopened meanwhile.
    func hide(after delay: Duration) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    /// The visible panel's frame in screen coordinates.
    private var panelScreenFrame: NSRect {
        panel.convertToScreen(panel.panelRect.isEmpty ? panel.frame : panel.panelRect)
    }

    /// "Link, Framer Motion — layout animations, from Safari, 2 minutes ago, 2 of 12".
    private func announceSelection() {
        guard AccessibilityAnnouncer.isVoiceOverRunning, let clip = model.selected else { return }
        let position = "\(model.selectedIndex + 1) of \(model.visible.count)"
        AccessibilityAnnouncer.announce("\(clip.accessibilityDescription(now: model.now)), \(position)")
    }

    // MARK: Keyboard

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard event.window === panel, panel.isKeyWindow else { return false }
        // Let an input method finish composing (Enter/Esc/arrows belong to it).
        guard !searchFocus.hasMarkedText else { return false }

        let context = KeyContext(
            isSearchFocused: searchFocus.isFocused,
            isQueryEmpty: model.query.isEmpty,
            layout: model.layout,
            isPreviewOpen: model.isPreviewOpen
        )
        guard let command = KeyRouter.command(for: KeyPress(event), in: context) else { return false }
        perform(command)
        return true
    }

    private func perform(_ command: KeyCommand) {
        switch command {
        case .moveSelection(let delta):
            model.moveSelection(by: delta)
            searchFocus.blur()
            announceSelection()
        case .copy:
            model.copySelected()
        case .paste:
            model.pasteSelected()
        case .togglePreview:
            model.togglePreview()
            searchFocus.blur()
        case .deleteSelected:
            model.delete()
        case .togglePin:
            model.togglePin()
        case .selectFilter(let filter):
            model.setFilter(filter)
            AccessibilityAnnouncer.announce("\(filter.title), \(model.visible.count) items")
        case .escape:
            let wasPreviewing = model.isPreviewOpen
            if !model.handleEscape() {
                hide()
            } else if !wasPreviewing {
                searchFocus.focus() // search was just cleared: ready to type again
            }
        case .close:
            hide()
        case .openSettings:
            openSettings?()
        case .focusSearch:
            searchFocus.focus()
        case .focusResults:
            searchFocus.blur()
        case .typeIntoSearch(let text):
            model.closePreview()
            searchFocus.insert(text)
        case .edit(let edit):
            searchFocus.perform(edit)
        case .ignore:
            break
        }
    }

    // MARK: Private

    private func rememberFrontmostApp() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = frontmost
        }
    }

    private func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// Sizes the window to the screen and centres the (row-layout) panel on it.
    private func position(on screen: NSScreen) {
        let visible = screen.visibleFrame
        let margins = PanelGeometry.margins
        let panelWidth = min(Metrics.Panel.maxWidth, visible.width - PanelGeometry.screenInset * 2)
        let size = NSSize(
            width: panelWidth + margins.leading + margins.trailing,
            height: PanelGeometry.maxPanelHeight + margins.top + margins.bottom
        )
        let panelTop = min(
            visible.midY + PanelGeometry.typicalPanelHeight / 2,
            visible.maxY - PanelGeometry.screenInset
        )
        let origin = NSPoint(
            x: (visible.midX - size.width / 2).rounded(),
            y: (panelTop + margins.top - size.height).rounded()
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }
}

// MARK: - Copy and paste

extension PanelController: PanelActionHandling {
    /// ↵: write to the pasteboard, confirm, then close.
    func copy(_ clip: ClipSnapshot) {
        Task {
            guard await write(clip) else { return }
            model.show(.copied)
            hide(after: Self.dismissDelayAfterCopy)
        }
    }

    /// ⌘↵: write to the pasteboard, close, hand focus back to the previous
    /// app and send it ⌘V. Without Accessibility this falls back to copy
    /// and explains (once) how to enable paste.
    func paste(_ clip: ClipSnapshot) {
        Task {
            guard await write(clip) else { return }
            guard AccessibilityPermission.isGranted else {
                model.show(.copied)
                hide(after: Self.dismissDelayAfterCopy)
                onboarding.presentIfNeeded()
                return
            }

            let target = previousApp
            let frame = panelScreenFrame
            let scheme = resolvedScheme
            hide()
            await activate(target)
            pasteService.sendPasteKeystroke()
            toastWindow.show(.pasted(into: target?.localizedName), panelFrame: frame, scheme: scheme)
        }
    }

    private func write(_ clip: ClipSnapshot) async -> Bool {
        guard let payload = await model.store.payload(for: clip.id), await pasteService.write(payload) else {
            Log.panel.error("Couldn't write item to the pasteboard")
            model.show(.failed)
            return false
        }
        return true
    }

    /// The panel never activates our app, so the previous app is normally
    /// still active; this covers the case where it isn't (e.g. Settings was open).
    private func activate(_ app: NSRunningApplication?) async {
        guard let app, !app.isTerminated else { return }
        if !app.isActive {
            app.activate()
            for _ in 0..<25 where !app.isActive {
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
        // Let the target's window become key again before the keystroke lands.
        try? await Task.sleep(for: .milliseconds(40))
    }

    private var resolvedScheme: ColorScheme {
        switch model.preferences.appearance {
        case .dark: return .dark
        case .light: return .light
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
    }
}

// MARK: - Benchmark

extension PanelController {
    /// `--benchmark-open`: opens and closes the panel repeatedly, timing the
    /// synchronous work up to the first frame (show, SwiftUI update,
    /// layout, display, Core Animation commit), prints the results and quits.
    func runOpenBenchmark(iterations: Int = 30) async {
        try? await Task.sleep(for: .seconds(1)) // let launch work settle
        var samples: [Double] = []
        for _ in 0..<iterations {
            hide()
            try? await Task.sleep(for: .milliseconds(80))
            let start = ContinuousClock.now
            show()
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.displayIfNeeded()
            CATransaction.flush()
            let elapsed = ContinuousClock.now - start
            samples.append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1_000)
        }
        hide()
        let warm = samples.dropFirst().sorted()
        let median = warm[warm.count / 2]
        let p95 = warm[min(warm.count - 1, Int(Double(warm.count) * 0.95))]
        print(String(
            format: "open-benchmark items=%d first=%.1fms median=%.1fms p95=%.1fms max=%.1fms",
            model.store.snapshots.count, samples[0], median, p95, warm.last ?? 0
        ))
        fflush(stdout)
        NSApp.terminate(nil)
    }
}

private extension KeyPress {
    init(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        self.init(
            keyCode: event.keyCode,
            characters: event.charactersIgnoringModifiers ?? "",
            typedCharacters: event.characters ?? "",
            modifiers: modifiers
        )
    }
}

/// Window content: the panel inset by the shadow margins, with the open
/// animation (scale 0.965→1, y +6→0, opacity 0→1).
private struct PanelWindowContent: View {
    let model: PanelModel
    let searchFocus: SearchFocus
    let onPanelFrameChange: (CGRect) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { window in
            RootView(model: model, searchFocus: searchFocus)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    // SwiftUI's global space is top-left origin; AppKit's window space is bottom-left.
                    onPanelFrameChange(CGRect(
                        x: frame.minX,
                        y: window.size.height - frame.maxY,
                        width: frame.width,
                        height: frame.height
                    ))
                }
                .scaleEffect(isOpen || reduceMotion ? 1 : 0.965)
                .offset(y: isOpen || reduceMotion ? 0 : 6)
                .opacity(isOpen ? 1 : 0)
                .padding(PanelGeometry.margins)
                .frame(width: window.size.width, height: window.size.height, alignment: .top)
        }
        .ignoresSafeArea()
    }

    private var isOpen: Bool { model.isPresented }
}

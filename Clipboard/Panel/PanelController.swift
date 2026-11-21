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

    func show() {
        guard !isVisible else { return }
        dismissTask?.cancel()
        rememberFrontmostApp()
        position(on: screenUnderMouse())
        model.hotkeyLabel = HotkeyLabel.current
        model.panelWillShow()

        panel.orderFrontRegardless()
        panel.makeKey()
        searchFocus.focus()

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
        case .escape:
            let wasPreviewing = model.isPreviewOpen
            if !model.handleEscape() {
                hide()
            } else if !wasPreviewing {
                searchFocus.focus() // search was just cleared: ready to type again
            }
        case .close:
            hide()
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

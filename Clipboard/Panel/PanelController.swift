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
    private let searchFocus = SearchFocus()
    private let panel = FloatingPanel()
    private var resignObserver: NSObjectProtocol?

    /// The app that was frontmost when the panel opened; paste goes back here.
    private(set) var previousApp: NSRunningApplication?

    var isVisible: Bool { panel.isVisible }

    init(model: PanelModel) {
        self.model = model

        let content = PanelWindowContent(model: model, searchFocus: searchFocus) { [weak panel] rect in
            panel?.panelRect = rect
        }
        let hostingView = NSHostingView(rootView: content)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onClickOutsidePanel = { [weak self] in self?.hide() }

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
        rememberFrontmostApp()
        position(on: screenUnderMouse())
        model.panelWillShow()

        panel.orderFrontRegardless()
        panel.makeKey()
        searchFocus.focus()

        withAnimation(Motion.panelOpen) {
            model.setPresented(true)
        }
    }

    func hide() {
        guard isVisible else { return }
        panel.orderOut(nil)
        model.panelDidHide()
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

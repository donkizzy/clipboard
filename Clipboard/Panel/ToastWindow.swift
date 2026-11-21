import AppKit
import SwiftUI

/// Shows a toast after the panel has closed, e.g. "Pasted → Notes", in a
/// small click-through window where the panel's toast would have been.
@MainActor
final class ToastWindow {
    private let window: NSPanel
    private let presenter = ToastPresenter()
    private var hideTask: Task<Void, Never>?

    private static let size = NSSize(width: 460, height: 120)

    init() {
        window = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        let hosting = NSHostingView(rootView: ToastHost(presenter: presenter))
        hosting.sizingOptions = []
        window.contentView = hosting
    }

    /// - Parameters:
    ///   - panelFrame: where the panel was, in screen coordinates
    ///   - scheme: the appearance the panel was using
    func show(_ toast: Toast, panelFrame: NSRect, scheme: ColorScheme) {
        hideTask?.cancel()
        let origin = NSPoint(
            x: (panelFrame.midX - Self.size.width / 2).rounded(),
            y: (panelFrame.minY + Metrics.Toast.bottomInset - Self.size.height / 2).rounded()
        )
        window.setFrame(NSRect(origin: origin, size: Self.size), display: false)
        presenter.scheme = scheme
        presenter.toast = nil
        window.orderFrontRegardless()
        presenter.toast = toast

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Metrics.Toast.visibleDuration)
            guard !Task.isCancelled else { return }
            self?.presenter.toast = nil
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.window.orderOut(nil)
        }
    }
}

@MainActor
@Observable
private final class ToastPresenter {
    var toast: Toast?
    var scheme: ColorScheme = .dark
}

private struct ToastHost: View {
    let presenter: ToastPresenter
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if let toast = presenter.toast {
                ToastView(toast: toast)
                    .transition(.asymmetric(
                        insertion: .offset(y: 10).combined(with: .opacity).animation(Motion.toast),
                        removal: .opacity.animation(.easeOut(duration: 0.18))
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.palette, Palette.resolve(presenter.scheme, reduceTransparency: reduceTransparency))
        .environment(\.colorScheme, presenter.scheme)
    }
}

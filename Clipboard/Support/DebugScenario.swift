#if DEBUG
import AppKit
import SwiftUI

/// Debug-only launch scenarios for screenshots and manual QA, e.g.
/// `Clipboard.app --demo --scenario preview --select 2`.
///
/// Combine with `-layout list` / `-appearance light`, which override the
/// stored preferences through the `NSArgumentDomain`.
@MainActor
enum DebugScenario {
    /// `--reduce-transparency`: renders as if the system setting were on,
    /// for checking the solid palette without changing system settings.
    static let forcesReduceTransparency = ProcessInfo.processInfo.arguments.contains("--reduce-transparency")

    static func apply(to environment: AppEnvironment, arguments: [String] = ProcessInfo.processInfo.arguments) {
        let model = environment.panelModel
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }

        if let index = value(after: "--select").flatMap(Int.init) {
            model.select(index: index)
        }
        if let query = value(after: "--query") {
            model.query = query
        }

        if arguments.contains("--backdrop") {
            Backdrop.show(dark: value(after: "-appearance") != "light")
        }

        switch value(after: "--scenario") {
        case "preview":
            model.openPreview()
        case "toast":
            // Delayed so the toast is mid-flight when a screenshot is taken.
            Task {
                try? await Task.sleep(for: .seconds(1))
                model.show(.copied)
            }
        case "empty":
            model.query = "no such item"
        case "settings-general":
            environment.showSettings(tab: .general)
        case "settings-privacy":
            environment.showSettings(tab: .privacy)
        case "settings-about":
            environment.showSettings(tab: .about)
        default:
            break
        }
    }
}

/// `--backdrop`: the design mock's wallpaper behind the panel, so README
/// screenshots show the vibrancy over a known image, not the real desktop.
@MainActor
private enum Backdrop {
    private static var window: NSWindow?

    static func show(dark: Bool) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: Wallpaper(dark: dark))
        window.orderFrontRegardless()
        self.window = window
    }

    /// `radial-gradient(130% 130% at 18% 0%, …)` from the design.
    private struct Wallpaper: View {
        let dark: Bool

        var body: some View {
            let stops: [Gradient.Stop] = dark
                ? [.init(color: Color(hex: 0x3A2D5C), location: 0), .init(color: Color(hex: 0x1E2246), location: 0.42), .init(color: Color(hex: 0x0C1230), location: 1)]
                : [.init(color: Color(hex: 0xDFE9FF), location: 0), .init(color: Color(hex: 0xEFE3FF), location: 0.46), .init(color: Color(hex: 0xFFE6EF), location: 1)]
            EllipticalGradient(stops: stops, center: UnitPoint(x: 0.18, y: 0), startRadiusFraction: 0, endRadiusFraction: 1.3)
                .ignoresSafeArea()
        }
    }
}
#endif

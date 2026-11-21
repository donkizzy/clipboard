#if DEBUG
import Foundation

/// Debug-only launch scenarios for screenshots and manual QA, e.g.
/// `Clipboard.app --demo --scenario preview --select 2`.
///
/// Combine with `-layout list` / `-appearance light`, which override the
/// stored preferences through the `NSArgumentDomain`.
@MainActor
enum DebugScenario {
    static func apply(to model: PanelModel, arguments: [String] = ProcessInfo.processInfo.arguments) {
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
        default:
            break
        }
    }
}
#endif

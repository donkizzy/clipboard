import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Until the global hotkey lands (M4), open the panel at launch so the
        // UI can be exercised; reopen it from the menu bar extra.
        environment.panelController.show()
        #if DEBUG
        DebugScenario.apply(to: environment.panelModel)
        #endif
    }
}

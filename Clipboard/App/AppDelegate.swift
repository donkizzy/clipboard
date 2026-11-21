import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    func applicationDidFinishLaunching(_ notification: Notification) {
        environment.start()
        #if DEBUG
        DebugScenario.apply(to: environment.panelModel)
        #endif
    }
}

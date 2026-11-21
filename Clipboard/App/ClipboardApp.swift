import SwiftUI

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Clipboard", systemImage: "clipboard") {
            Button("Open Clipboard") {
                appDelegate.environment.panelController.show()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Divider()

            Button("Quit Clipboard") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

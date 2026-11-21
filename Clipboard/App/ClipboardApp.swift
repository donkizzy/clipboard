import KeyboardShortcuts
import SwiftUI

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(environment: appDelegate.environment, preferences: appDelegate.environment.preferences)
        } label: {
            MenuBarIcon(preferences: appDelegate.environment.preferences)
        }
    }
}

/// The menu bar glyph; shows a paused state while capture is paused.
private struct MenuBarIcon: View {
    let preferences: Preferences

    var body: some View {
        Image(systemName: preferences.isCapturePaused ? "pause.circle" : "clipboard")
            .accessibilityLabel(preferences.isCapturePaused ? "Clipboard (paused)" : "Clipboard")
    }
}

private struct MenuBarMenu: View {
    let environment: AppEnvironment
    @Bindable var preferences: Preferences

    var body: some View {
        Button("Open Clipboard") {
            environment.panelController.show()
        }
        .globalKeyboardShortcut(.togglePanel)

        Toggle("Pause Capture", isOn: $preferences.isCapturePaused)
            .disabled(!environment.capturesClipboard)

        Button("Clear History…") {
            environment.confirmClearHistory()
        }

        Divider()

        Button("Settings…") {
            environment.showSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Clipboard") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

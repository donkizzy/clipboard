import AppKit
import SwiftUI

/// Hosts `SettingsView` in a window we own.
///
/// SwiftUI's `Settings` scene is unreliable in a menu-bar (LSUIElement)
/// app: it opens behind other windows and can't be shown from AppKit code
/// such as the panel's ⌘, shortcut. Owning the window fixes both.
@MainActor
final class SettingsWindowController {
    private let preferences: Preferences
    private let launchAtLogin = LaunchAtLogin()
    private let actions: SettingsActions
    private let tabState = SettingsTabState()
    private var window: NSWindow?

    init(preferences: Preferences, actions: SettingsActions) {
        self.preferences = preferences
        self.actions = actions
    }

    func show(tab: SettingsTab? = nil) {
        if let tab { tabState.tab = tab }
        let window = window ?? makeWindow()
        self.window = window
        launchAtLogin.refresh()
        NSApp.activate()
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsRoot(preferences: preferences, launchAtLogin: launchAtLogin, actions: actions, tabState: tabState)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.title = "Clipboard Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SettingsWindow")
        return window
    }
}

@MainActor
@Observable
private final class SettingsTabState {
    var tab: SettingsTab = .general
}

private struct SettingsRoot: View {
    let preferences: Preferences
    let launchAtLogin: LaunchAtLogin
    let actions: SettingsActions
    @Bindable var tabState: SettingsTabState

    var body: some View {
        SettingsView(preferences: preferences, launchAtLogin: launchAtLogin, actions: actions, tab: $tabState.tab)
    }
}

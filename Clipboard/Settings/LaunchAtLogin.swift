import Foundation
import Observation
import ServiceManagement

/// "Launch at login" via `SMAppService.mainApp`. The system owns this
/// state (the user can change it in System Settings › Login Items), so it is
/// read from `SMAppService` rather than stored in preferences.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = false
    /// Registered, but the user must still approve it in System Settings.
    private(set) var requiresApproval = false
    private(set) var lastError: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
            Log.panel.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

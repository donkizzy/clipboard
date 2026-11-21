import AppKit

/// Speaks short status changes through VoiceOver (toasts, keyboard
/// selection), which would otherwise go unnoticed: VoiceOver's cursor stays
/// in the search field while the arrow keys move the panel's own selection.
@MainActor
enum AccessibilityAnnouncer {
    static var isVoiceOverRunning: Bool { NSWorkspace.shared.isVoiceOverEnabled }

    static func announce(_ message: String, priority: NSAccessibilityPriorityLevel = .high) {
        guard isVoiceOverRunning else { return }
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: priority.rawValue]
        )
    }
}

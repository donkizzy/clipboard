import AppKit
import ApplicationServices

/// The Accessibility (TCC) permission that paste-back needs to post ⌘V.
enum AccessibilityPermission {
    static var isGranted: Bool { AXIsProcessTrusted() }

    /// Adds Clipboard to the Accessibility list and shows the system prompt.
    static func requestWithSystemPrompt() {
        // The string value of kAXTrustedCheckOptionPrompt, which Swift 6
        // treats as a non-concurrency-safe global.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

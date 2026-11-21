import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Toggles the panel from anywhere. ⌘⇧V by default; configurable in Settings.
    static let togglePanel = Self("togglePanel", initial: .init(.v, modifiers: [.command, .shift]))
}

enum HotkeyLabel {
    /// The current toggle shortcut for display, e.g. "⌘⇧V", or `nil` if the
    /// user cleared it.
    ///
    /// Modifiers are listed command-first to match the design ("⌘⇧V"),
    /// rather than AppKit's control-first menu order ("⇧⌘V").
    @MainActor
    static var current: String? {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .togglePanel) else { return nil }
        return format(modifiers: shortcut.modifiers, key: keyLabel(for: shortcut))
    }

    static func format(modifiers: NSEvent.ModifierFlags, key: String) -> String {
        let symbols: [(NSEvent.ModifierFlags, String)] = [(.command, "⌘"), (.shift, "⇧"), (.option, "⌥"), (.control, "⌃")]
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + key
    }

    /// The key part of the library's description (which leads with modifier symbols).
    @MainActor
    private static func keyLabel(for shortcut: KeyboardShortcuts.Shortcut) -> String {
        let modifierSymbols: Set<Character> = ["⌘", "⇧", "⌥", "⌃", "🌐"]
        return String(shortcut.description.drop { modifierSymbols.contains($0) })
    }
}

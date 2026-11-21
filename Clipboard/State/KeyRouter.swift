import Foundation

/// A panel action triggered from the keyboard.
enum KeyCommand: Equatable, Sendable {
    /// Move the selection by ±1 (and hand focus to the results).
    case moveSelection(Int)
    case copy
    case paste
    case togglePreview
    case deleteSelected
    case togglePin
    case selectFilter(HistoryFilter)
    /// Close preview → clear search → close panel, in that order.
    case escape
    case close
    case focusSearch
    case focusResults
    /// A printable keystroke while the results have focus: refocus the
    /// search field and type it there.
    case typeIntoSearch(String)
    /// A standard editing shortcut for the search field. The panel's app has
    /// no Edit menu (it's a menu bar app), so these are routed by hand.
    case edit(TextEdit)
    /// Swallow the key, so AppKit doesn't beep at an unhandled keystroke.
    case ignore

    enum TextEdit: Sendable {
        case selectAll, copy, cut, paste, undo, redo
    }
}

/// A key press, reduced to what routing needs.
struct KeyPress: Equatable, Sendable {
    struct Modifiers: OptionSet, Hashable, Sendable {
        let rawValue: Int
        static let command = Modifiers(rawValue: 1 << 0)
        static let shift = Modifiers(rawValue: 1 << 1)
        static let option = Modifiers(rawValue: 1 << 2)
        static let control = Modifiers(rawValue: 1 << 3)
    }

    /// Virtual key code (`kVK_*`).
    var keyCode: UInt16
    /// `charactersIgnoringModifiers`, lowercased for letter shortcuts.
    var characters: String
    /// The characters the key actually types, used for `typeIntoSearch`.
    var typedCharacters: String
    var modifiers: Modifiers = []

    enum Key {
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let tab: UInt16 = 48
        static let space: UInt16 = 49
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let escape: UInt16 = 53
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }
}

/// The panel state that changes what a key means.
struct KeyContext: Equatable, Sendable {
    var isSearchFocused: Bool
    var isQueryEmpty: Bool
    var layout: PanelLayout
    var isPreviewOpen: Bool
}

/// Maps key presses to panel commands: the whole keyboard map from the spec,
/// as one pure, unit-tested function. `nil` means "let the search field have it".
enum KeyRouter {
    static func command(for press: KeyPress, in context: KeyContext) -> KeyCommand? {
        let mods = press.modifiers
        let key = KeyPress.Key.self

        if mods.contains(.command) {
            return commandShortcut(press, context)
        }
        // Option/Control combos are text navigation (⌥← word jump, ⌃A…).
        if !mods.isDisjoint(with: [.option, .control]) {
            return context.isSearchFocused ? nil : .ignore
        }

        switch press.keyCode {
        case key.returnKey, key.keypadEnter:
            return .copy
        case key.escape:
            return .escape
        case key.up:
            return .moveSelection(-1)
        case key.down:
            return .moveSelection(1)
        case key.left, key.right:
            // Horizontal arrows navigate cards only in the row layout, and only
            // when they wouldn't otherwise move the caret through a query.
            guard context.layout == .row else { return context.isSearchFocused ? nil : .ignore }
            guard !context.isSearchFocused || context.isQueryEmpty else { return nil }
            return .moveSelection(press.keyCode == key.left ? -1 : 1)
        case key.tab:
            if mods.contains(.shift) { return .focusSearch }
            return context.isSearchFocused ? .focusResults : .focusSearch
        case key.space where context.isPreviewOpen || !context.isSearchFocused:
            return .togglePreview
        case key.delete, key.forwardDelete:
            return context.isSearchFocused ? nil : .deleteSelected
        default:
            guard !context.isSearchFocused else { return nil }
            return isPrintable(press.typedCharacters) ? .typeIntoSearch(press.typedCharacters) : .ignore
        }
    }

    private static func commandShortcut(_ press: KeyPress, _ context: KeyContext) -> KeyCommand? {
        let shift = press.modifiers.contains(.shift)
        if press.keyCode == KeyPress.Key.returnKey || press.keyCode == KeyPress.Key.keypadEnter {
            return .paste
        }
        switch press.characters.lowercased() {
        case "p": return .togglePin
        case "w": return .close
        case "1", "2", "3", "4", "5", "6":
            let index = Int(press.characters)! - 1
            return .selectFilter(HistoryFilter.allCases[index])
        case "a" where context.isSearchFocused: return .edit(.selectAll)
        case "c": return context.isSearchFocused ? .edit(.copy) : .copy
        case "x" where context.isSearchFocused: return .edit(.cut)
        case "v" where context.isSearchFocused && !shift: return .edit(.paste)
        case "z" where context.isSearchFocused: return .edit(shift ? .redo : .undo)
        default: return nil
        }
    }

    /// True for text a user would expect to land in the search field:
    /// no control characters and no function-key private-use scalars.
    static func isPrintable(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        return string.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && !(0xF700...0xF8FF).contains(scalar.value)
        }
    }
}

import Testing
@testable import Clipboard

@Suite("KeyRouter")
struct KeyRouterTests {
    typealias Key = KeyPress.Key

    private func press(_ keyCode: UInt16, _ chars: String = "", _ modifiers: KeyPress.Modifiers = []) -> KeyPress {
        KeyPress(keyCode: keyCode, characters: chars, typedCharacters: chars, modifiers: modifiers)
    }

    private func context(
        focused: Bool = true,
        queryEmpty: Bool = true,
        layout: PanelLayout = .row,
        preview: Bool = false
    ) -> KeyContext {
        KeyContext(isSearchFocused: focused, isQueryEmpty: queryEmpty, layout: layout, isPreviewOpen: preview)
    }

    private func route(_ press: KeyPress, _ context: KeyContext) -> KeyCommand? {
        KeyRouter.command(for: press, in: context)
    }

    // MARK: Navigation

    @Test("↑/↓ move the selection in both layouts, focused or not", arguments: [PanelLayout.row, .list])
    func verticalArrows(layout: PanelLayout) {
        for focused in [true, false] {
            #expect(route(press(Key.up), context(focused: focused, queryEmpty: false, layout: layout)) == .moveSelection(-1))
            #expect(route(press(Key.down), context(focused: focused, queryEmpty: false, layout: layout)) == .moveSelection(1))
        }
    }

    @Test("←/→ navigate cards when the search is empty or unfocused")
    func horizontalArrowsInRow() {
        #expect(route(press(Key.left), context(focused: true, queryEmpty: true)) == .moveSelection(-1))
        #expect(route(press(Key.right), context(focused: false, queryEmpty: false)) == .moveSelection(1))
    }

    @Test("←/→ move the caret while editing a non-empty query")
    func horizontalArrowsWhileEditing() {
        #expect(route(press(Key.left), context(focused: true, queryEmpty: false)) == nil)
        #expect(route(press(Key.right), context(focused: true, queryEmpty: false)) == nil)
    }

    @Test("←/→ don't navigate in the list layout")
    func horizontalArrowsInList() {
        #expect(route(press(Key.left), context(focused: true, layout: .list)) == nil)
        #expect(route(press(Key.right), context(focused: false, layout: .list)) == .ignore)
    }

    @Test("Option-arrows stay text navigation")
    func optionArrows() {
        #expect(route(press(Key.left, "", .option), context(focused: true, queryEmpty: false)) == nil)
    }

    // MARK: Actions

    @Test("↵ copies and ⌘↵ pastes, regardless of focus")
    func returnKeys() {
        for focused in [true, false] {
            #expect(route(press(Key.returnKey), context(focused: focused)) == .copy)
            #expect(route(press(Key.keypadEnter), context(focused: focused)) == .copy)
            #expect(route(press(Key.returnKey, "\r", .command), context(focused: focused)) == .paste)
        }
    }

    @Test("Space previews only when the search isn't focused")
    func space() {
        #expect(route(press(Key.space, " "), context(focused: true)) == nil)
        #expect(route(press(Key.space, " "), context(focused: false)) == .togglePreview)
    }

    @Test("Space always closes an open preview")
    func spaceClosesPreview() {
        #expect(route(press(Key.space, " "), context(focused: true, preview: true)) == .togglePreview)
    }

    @Test("⌫ and Delete remove the selection only when the search isn't focused")
    func delete() {
        #expect(route(press(Key.delete), context(focused: true)) == nil)
        #expect(route(press(Key.forwardDelete), context(focused: true)) == nil)
        #expect(route(press(Key.delete), context(focused: false)) == .deleteSelected)
        #expect(route(press(Key.forwardDelete), context(focused: false)) == .deleteSelected)
    }

    @Test("⌘P toggles pin")
    func pin() {
        #expect(route(press(35, "p", .command), context()) == .togglePin)
    }

    @Test("⌘1…⌘6 select the filters in order")
    func filters() {
        for (index, filter) in HistoryFilter.allCases.enumerated() {
            #expect(route(press(18, "\(index + 1)", .command), context()) == .selectFilter(filter))
        }
        #expect(route(press(26, "7", .command), context()) == nil)
    }

    @Test("Esc always routes to the layered escape")
    func escape() {
        #expect(route(press(Key.escape), context(focused: true)) == .escape)
        #expect(route(press(Key.escape), context(focused: false, preview: true)) == .escape)
    }

    // MARK: Focus and typing

    @Test("Tab moves focus between search and results")
    func tab() {
        #expect(route(press(Key.tab), context(focused: true)) == .focusResults)
        #expect(route(press(Key.tab), context(focused: false)) == .focusSearch)
        #expect(route(press(Key.tab, "", .shift), context(focused: false)) == .focusSearch)
    }

    @Test("Printable keys go to the search field")
    func typing() {
        #expect(route(press(0, "a"), context(focused: true)) == nil)
        #expect(route(press(0, "a"), context(focused: false)) == .typeIntoSearch("a"))
        #expect(route(press(0, "é"), context(focused: false)) == .typeIntoSearch("é"))
    }

    @Test("Function keys are swallowed, not typed", arguments: ["\u{F704}", "\u{1B}", ""])
    func nonPrintable(chars: String) {
        #expect(route(press(122, chars), context(focused: false)) == .ignore)
    }

    @Test("Editing shortcuts reach the field only while it's focused")
    func editing() {
        #expect(route(press(0, "a", .command), context(focused: true)) == .edit(.selectAll))
        #expect(route(press(9, "v", .command), context(focused: true)) == .edit(.paste))
        #expect(route(press(6, "z", [.command, .shift]), context(focused: true)) == .edit(.redo))
        #expect(route(press(8, "c", .command), context(focused: true)) == .edit(.copy))
        #expect(route(press(8, "c", .command), context(focused: false)) == .copy)
        #expect(route(press(0, "a", .command), context(focused: false)) == nil)
    }

    @Test("⌘, opens Settings and ⌘W closes")
    func windowShortcuts() {
        #expect(route(press(43, ",", .command), context()) == .openSettings)
        #expect(route(press(13, "w", .command), context()) == .close)
    }

    @Test("⌘⇧V passes through to the global hotkey")
    func hotkeyPassesThrough() {
        #expect(route(press(9, "v", [.command, .shift]), context(focused: true)) == nil)
    }
}

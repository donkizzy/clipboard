import AppKit
import SwiftUI

/// Owns keyboard focus for the search field.
///
/// The panel's key handling needs to know whether the field is focused
/// (Space and ⌫ act on the selection only when it isn't), and needs to put the
/// caret at the end when it refocuses the field after a keystroke. SwiftUI's
/// `FocusState` can do neither: focusing an `NSTextField` through it selects
/// all text. So the field is AppKit-backed and this object drives it directly.
@MainActor
final class SearchFocus {
    fileprivate weak var field: SearchTextField?

    var isFocused: Bool {
        guard let field, let editor = field.currentEditor() else { return false }
        return field.window?.firstResponder === editor
    }

    /// Focuses the field with the caret after the last character.
    func focus() {
        guard let field, let window = field.window else { return }
        if !isFocused { window.makeFirstResponder(field) }
        if let editor = field.currentEditor() {
            editor.selectedRange = NSRange(location: (editor.string as NSString).length, length: 0)
        }
    }

    /// Moves focus to the results, so Space and ⌫ act on the selection.
    func blur() {
        guard isFocused, let window = field?.window else { return }
        window.makeFirstResponder(window.contentView)
    }
}

struct SearchBar: View {
    @Environment(\.palette) private var palette
    @Binding var query: String
    let focus: SearchFocus
    var shortcutLabel = "⌘⇧V"

    var body: some View {
        HStack(spacing: Metrics.SearchBar.spacing) {
            GlyphStroke(Glyph.Magnifier(), width: 2, size: Metrics.SearchBar.iconSize)
                .foregroundStyle(palette.textDim)
                .accessibilityHidden(true)

            SearchFieldRepresentable(
                text: $query,
                placeholder: "Search clipboard…",
                textColor: NSColor(palette.text),
                placeholderColor: NSColor(palette.textFaint),
                focus: focus
            )
            .frame(maxWidth: .infinity)
            .frame(height: 23)

            Text(shortcutLabel)
                .textStyle(Typography.shortcutChip)
                .foregroundStyle(palette.textDim)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(palette.chip, in: RoundedRectangle(cornerRadius: Metrics.SearchBar.chipRadius, style: .continuous))
                .fixedSize()
                .accessibilityLabel("Shortcut: Command Shift V")
        }
        .padding(Metrics.SearchBar.padding)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

// MARK: - AppKit field

private struct SearchFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let textColor: NSColor
    let placeholderColor: NSColor
    let focus: SearchFocus

    private static let font = NSFont.systemFont(ofSize: 19, weight: .regular)
    private static let kern: CGFloat = -0.19 // -0.01em at 19pt

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> SearchTextField {
        let field = SearchTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.font = Self.font
        field.kern = Self.kern
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setAccessibilityLabel("Search clipboard")
        field.setAccessibilityIdentifier("searchField")
        focus.field = field
        update(field)
        return field
    }

    func updateNSView(_ field: SearchTextField, context: Context) {
        context.coordinator.text = $text
        focus.field = field
        update(field)
    }

    private func update(_ field: SearchTextField) {
        field.textColor = textColor
        field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .font: Self.font,
            .foregroundColor: placeholderColor,
            .kern: Self.kern,
        ])
        if field.stringValue != text {
            field.stringValue = text
            field.applyEditorAttributes()
        }
        field.insertionColor = textColor
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

/// Borderless text field that applies the design's letter-spacing and caret
/// colour to its field editor, which otherwise ignores both.
final class SearchTextField: NSTextField {
    var kern: CGFloat = 0
    var insertionColor: NSColor = .labelColor {
        didSet { applyEditorAttributes() }
    }

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome { applyEditorAttributes() }
        return didBecome
    }

    func applyEditorAttributes() {
        guard let editor = currentEditor() as? NSTextView else { return }
        var attributes = editor.typingAttributes
        attributes[.kern] = kern
        if let font { attributes[.font] = font }
        if let textColor { attributes[.foregroundColor] = textColor }
        editor.typingAttributes = attributes
        editor.insertionPointColor = insertionColor
        if let storage = editor.textStorage, storage.length > 0 {
            storage.addAttributes(attributes, range: NSRange(location: 0, length: storage.length))
        }
    }
}

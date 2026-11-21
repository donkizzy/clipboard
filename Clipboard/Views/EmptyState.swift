import SwiftUI

struct EmptyState: View {
    enum Kind: Equatable {
        /// A search with no results (the design's state).
        case noMatches
        /// A filter tab with nothing in it, e.g. no pinned items yet.
        case emptyFilter(HistoryFilter)
        /// Nothing recorded yet.
        case noHistory
    }

    @Environment(\.palette) private var palette
    var kind: Kind = .noMatches

    private var copy: (title: String, message: String) {
        switch kind {
        case .noMatches:
            ("No matches", "Nothing in your clipboard history fits this search.")
        case .emptyFilter(.pinned):
            ("No pinned items", "Pin an item with ⌘P to keep it here for good.")
        case .emptyFilter(let filter):
            ("No \(filter.title.lowercased()) yet", "Copied \(filter.title.lowercased()) will show up here.")
        case .noHistory:
            ("Nothing copied yet", "Copy something and it will appear here.")
        }
    }

    var body: some View {
        let copy = copy
        VStack(spacing: 10) {
            ClipboardGlyph(color: palette.textFaint, size: 40)
                .accessibilityHidden(true)
            Text(copy.title)
                .textStyle(Typography.emptyTitle)
                .foregroundStyle(palette.textDim)
            Text(copy.message)
                .textStyle(Typography.emptyBody)
                .foregroundStyle(palette.textFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 64)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("emptyState")
    }
}

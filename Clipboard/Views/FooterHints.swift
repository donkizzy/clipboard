import SwiftUI

struct FooterHints: View {
    @Environment(\.palette) private var palette
    let itemCount: Int

    private static let hints: [(key: String, label: String)] = [
        ("↵", "Copy"),
        ("⌘↵", "Paste"),
        ("Space", "Preview"),
        ("←\u{200C}→", "Navigate"), // ZWNJ stops the arrows fusing into ↔
        ("⌫", "Delete"),
    ]

    var body: some View {
        HStack(spacing: Metrics.Footer.spacing) {
            ForEach(Self.hints, id: \.key) { hint in
                HStack(spacing: 6) {
                    KeyChip(key: hint.key)
                    Text(hint.label)
                        .textStyle(Typography.footerLabel)
                        .foregroundStyle(palette.textDim)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
            Text(itemCount == 1 ? "1 item" : "\(itemCount) items")
                .textStyle(Typography.footerLabel)
                .foregroundStyle(palette.textFaint)
                .accessibilityIdentifier("itemCount")
        }
        .lineLimit(1)
        .padding(Metrics.Footer.padding)
        .background(palette.footer)
        .overlay(alignment: .top) { Hairline() }
    }
}

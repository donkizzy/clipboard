import SwiftUI

struct EmptyState: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            ClipboardGlyph(color: palette.textFaint, size: 40)
                .accessibilityHidden(true)
            Text("No matches")
                .textStyle(Typography.emptyTitle)
                .foregroundStyle(palette.textDim)
            Text("Nothing in your clipboard history fits this search.")
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

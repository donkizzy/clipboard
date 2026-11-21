import SwiftUI

/// One row in the list layout.
struct ListRowView: View {
    @Environment(\.palette) private var palette
    @State private var isHovered = false

    let clip: ClipSnapshot
    let isSelected: Bool
    let now: Date
    let actions: ClipActions

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.List.rowRadius, style: .continuous)
    }

    var body: some View {
        HStack(spacing: 12) {
            ListThumb(clip: clip)
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.title)
                    .textStyle(Typography.listTitle)
                    .foregroundStyle(palette.text)
                Text(clip.subtitle)
                    .textStyle(Typography.listSubtitle)
                    .foregroundStyle(palette.textDim)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)

            if clip.isPinned {
                Glyph.Pin().fill(palette.accent).frame(width: 13, height: 13)
            }
            Text(RelativeTime.short(clip.createdAt, now: now))
                .textStyle(Typography.listTime)
                .foregroundStyle(palette.textFaint)
                .fixedSize()
            TypeBadge(label: clip.typeBadge)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .padding(1) // the design's always-present 1px border
        .frame(height: Metrics.List.rowHeight)
        .background(background, in: shape)
        .overlay { shape.strokeBorder(isSelected ? palette.cardSelBorder : .clear, lineWidth: 1) }
        .contentShape(shape)
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .trackHover($isHovered)
        .onTapGesture(count: 2) { actions.openPreview(clip.id) }
        .onTapGesture { actions.select(clip.id) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(clip.accessibilityDescription(now: now))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("row.\(clip.id.uuidString)")
        .accessibilityAction(named: "Preview") { actions.openPreview(clip.id) }
        .accessibilityAction(named: clip.isPinned ? "Unpin" : "Pin") { actions.togglePin(clip.id) }
        .accessibilityAction(named: "Delete") { actions.delete(clip.id) }
    }

    private var background: Color {
        if isSelected { return palette.cardSel }
        return isHovered ? palette.cardHover : .clear
    }
}

/// 38pt leading thumbnail or icon for a list row.
private struct ListThumb: View {
    @Environment(\.palette) private var palette
    let clip: ClipSnapshot

    private var size: CGFloat { Metrics.List.thumbSize }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.List.thumbRadius, style: .continuous)
    }

    var body: some View {
        switch clip.content {
        case .image(let image):
            ImageArtwork(image: image)
                .frame(width: size, height: size)
                .clipShape(shape)

        case .link(let link):
            FaviconTile(link: link, size: size, radius: Metrics.List.thumbRadius, style: Typography.faviconInitialLarge)

        case .file(let file):
            let accent = file.accent?.color ?? palette.accent
            tile(palette.accentSoft) {
                if file.isDirectory {
                    Glyph.FolderBack().fill(accent)
                } else {
                    Glyph.DocumentSmall().fill(accent).opacity(0.85)
                }
            }

        case .text:
            tile(palette.chip) {
                GlyphStroke(Glyph.TextLines(), width: 2, size: 19)
                    .foregroundStyle(palette.textDim)
            }
        }
    }

    private func tile(_ fill: Color, @ViewBuilder glyph: () -> some View) -> some View {
        shape.fill(fill)
            .frame(width: size, height: size)
            .overlay { glyph().frame(width: 20, height: 20) }
    }
}

import SwiftUI

/// One 176×186 card in the row layout.
struct CardView: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    let clip: ClipSnapshot
    let isSelected: Bool
    let now: Date
    let actions: ClipActions

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.Card.radius, style: .continuous)
    }

    private var isLifted: Bool { isHovered && !reduceMotion }

    var body: some View {
        VStack(spacing: 0) {
            CardMedia(clip: clip)
                .frame(height: Metrics.Card.mediaHeight)
                .frame(maxWidth: .infinity)
                .clipped()
            Spacer(minLength: 0)
            footer
        }
        .padding(Metrics.Card.borderWidth)
        .frame(width: Metrics.Card.width, height: Metrics.Card.height)
        .background(isSelected ? palette.cardSel : palette.card)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(isSelected ? palette.cardSelBorder : palette.cardBorder, lineWidth: Metrics.Card.borderWidth)
        }
        .overlay(alignment: .topLeading) {
            if clip.isPinned { pinBadge.padding(Metrics.Card.borderWidth + 8) }
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                selectionActions
                    .padding(.top, Metrics.Card.borderWidth + 7)
                    .padding(.trailing, Metrics.Card.borderWidth + 8)
                    .transition(.opacity.animation(Motion.fade))
            }
        }
        .outerShadow(shape, shadow)
        .contentShape(shape)
        .offset(y: isLifted ? -Metrics.Card.hoverLift : 0)
        .animation(Motion.hover, value: isLifted)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .trackHover($isHovered)
        .onTapGesture(count: 2) { actions.openPreview(clip.id) }
        .onTapGesture { actions.select(clip.id) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(clip.accessibilityDescription(now: now))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("card.\(clip.id.uuidString)")
        .accessibilityAction(named: "Preview") { actions.openPreview(clip.id) }
        .accessibilityAction(named: clip.isPinned ? "Unpin" : "Pin") { actions.togglePin(clip.id) }
        .accessibilityAction(named: "Delete") { actions.delete(clip.id) }
    }

    private var shadow: ShadowLayer {
        if isHovered { return .cardHover }
        return isSelected ? .cardSelected : .card
    }

    private var footer: some View {
        HStack(spacing: 7) {
            AppBadge(clip: clip, size: 15, radius: 4, fontSize: 8)
            Text(clip.sourceName)
                .textStyle(Typography.appName)
                .foregroundStyle(palette.textDim)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(RelativeTime.short(clip.createdAt, now: now))
                .textStyle(Typography.cardTime)
                .foregroundStyle(palette.textFaint)
                .fixedSize()
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(palette.cardFoot)
        .overlay(alignment: .top) { Hairline() }
    }

    private var pinBadge: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(palette.accent)
            .frame(width: Metrics.Card.pinBadgeSize, height: Metrics.Card.pinBadgeSize)
            .overlay { Glyph.Pin().fill(.white).frame(width: 11, height: 11) }
            .cssShadow(.pinBadge)
    }

    private var selectionActions: some View {
        HStack(spacing: 5) {
            GlassIconButton(hoverFill: palette.accent, help: clip.isPinned ? "Unpin" : "Pin") {
                actions.togglePin(clip.id)
            } label: {
                Glyph.Pin().fill().frame(width: 12, height: 12)
            }
            GlassIconButton(hoverFill: Palette.destructive, help: "Delete") {
                actions.delete(clip.id)
            } label: {
                GlyphStroke(Glyph.Close(), width: 2.2, size: 12)
            }
        }
    }
}

/// 24pt translucent button floating over the selected card.
private struct GlassIconButton<Label: View>: View {
    @Environment(\.palette) private var palette
    @State private var isHovered = false

    let hoverFill: Color
    let help: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        Button(action: action) {
            label()
                .foregroundStyle(isHovered ? Color.white : palette.text)
                .frame(width: Metrics.Card.actionButtonSize, height: Metrics.Card.actionButtonSize)
                .background {
                    if isHovered {
                        shape.fill(hoverFill)
                    } else {
                        shape.fill(palette.glass)
                            .background(palette.isTranslucent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear), in: shape)
                    }
                }
                .cssShadow(.glassButton)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .trackHover($isHovered)
    }
}

// MARK: - Media

/// The 104pt-tall top area of a card, by item kind.
private struct CardMedia: View {
    @Environment(\.palette) private var palette
    let clip: ClipSnapshot

    var body: some View {
        switch clip.content {
        case .text(let text):
            Text(text.preview)
                .textStyle(text.isCode ? Typography.cardCode : Typography.cardBody)
                .foregroundStyle(palette.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(EdgeInsets(top: 32, leading: 14, bottom: 13, trailing: 14))

        case .link(let link):
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    FaviconTile(link: link, size: 26, radius: 7, style: Typography.faviconInitialSmall)
                    Text(link.domain)
                        .textStyle(Typography.linkDomain)
                        .foregroundStyle(palette.textDim)
                        .lineLimit(1)
                }
                Text(link.title ?? clip.title)
                    .textStyle(Typography.linkTitle)
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(EdgeInsets(top: 14, leading: 14, bottom: 10, trailing: 14))

        case .image(let image):
            ImageArtwork(image: image)
                .overlay(alignment: .bottomLeading) {
                    DimensionChip(label: image.dimensionLabel)
                        .padding(8)
                }

        case .file(let file):
            let accent = file.accent?.color ?? palette.accent
            Group {
                if file.isDirectory {
                    FolderGlyph(color: accent, size: 52)
                } else {
                    DocumentGlyph(color: accent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// "2880×1620" chip over image artwork.
private struct DimensionChip: View {
    @Environment(\.palette) private var palette
    let label: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        Text(label)
            .textStyle(Typography.dimensionChip)
            .foregroundStyle(.white.opacity(0.92))
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background {
                shape.fill(.black.opacity(0.32))
                    .background(palette.isTranslucent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear), in: shape)
                    .environment(\.colorScheme, .dark)
            }
    }
}

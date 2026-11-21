import SwiftUI

extension RGBColor {
    var color: Color { Color(hex: hex) }
}

extension GradientPair {
    /// CSS `linear-gradient(140deg, start, end)`.
    var linearGradient: LinearGradient {
        // 140° measured clockwise from "to top" → direction (sin, −cos) in y-down space.
        let angle = 140.0 * .pi / 180
        let dx = sin(angle) / 2
        let dy = -cos(angle) / 2
        return LinearGradient(
            colors: [start.color, end.color],
            startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
            endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
        )
    }
}

/// A 0.5pt hairline in the `sep` colour.
struct Hairline: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Rectangle()
            .fill(palette.sep)
            .frame(height: 0.5)
    }
}

/// Rounded-square badge for the source app: its tint plus initial.
struct AppBadge: View {
    let clip: ClipSnapshot
    let size: CGFloat
    let radius: CGFloat
    let fontSize: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(clip.source?.tint?.color ?? Color(hex: 0x888888))
            .frame(width: size, height: size)
            .overlay {
                Text(clip.sourceInitial)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// Placeholder favicon: the link's gradient with the domain's initial.
struct FaviconTile: View {
    let link: ClipContent.Link
    let size: CGFloat
    let radius: CGFloat
    let style: TextStyle

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(link.resolvedArtwork.linearGradient)
            .frame(width: size, height: size)
            .overlay {
                Text(link.initial)
                    .textStyle(style)
                    .foregroundStyle(.white)
            }
    }
}

/// Image artwork: the thumbnail (or full image) when available, otherwise
/// the placeholder gradient. Fills its frame, cropping to fit.
struct ImageArtwork: View {
    let image: ClipContent.Image
    var preferFullSize = false

    @State private var loaded: NSImage?

    private var url: URL? {
        preferFullSize ? (image.imageURL ?? image.thumbnailURL) : (image.thumbnailURL ?? image.imageURL)
    }

    /// Thumbnails are already 352px wide; previews decode for 440pt @2x.
    private var maxPixelSize: Int { preferFullSize ? 1_320 : Thumbnailer.maxThumbnailPixels }

    var body: some View {
        let shown = loaded ?? url.flatMap { ImageCache.shared.cachedImage(at: $0, maxPixelSize: maxPixelSize) }
        Rectangle()
            .fill(image.resolvedArtwork.linearGradient)
            .overlay {
                if let shown {
                    Image(nsImage: shown)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: url) {
                guard let url else { return }
                loaded = await ImageCache.shared.image(at: url, maxPixelSize: maxPixelSize)
            }
    }
}

/// Small rounded label, e.g. "Link" or "Code".
struct TypeBadge: View {
    @Environment(\.palette) private var palette
    let label: String
    var style: TextStyle = Typography.typeBadge
    var padding = EdgeInsets(top: 3, leading: 7, bottom: 3, trailing: 7)
    var radius: CGFloat = 6

    var body: some View {
        Text(label)
            .textStyle(style)
            .foregroundStyle(palette.chipText)
            .padding(padding)
            .background(palette.chip, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .fixedSize()
    }
}

/// Keyboard key chip used in the footer hints.
struct KeyChip: View {
    @Environment(\.palette) private var palette
    let key: String

    var body: some View {
        Text(key)
            // SF Mono lacks ⌫ and ↵; symbol-only keys use SF Pro, which has them.
            .textStyle(key.contains(where: \.isLetter) ? Typography.footerKey : Typography.footerKeySymbol)
            .foregroundStyle(palette.textDim)
            .padding(.horizontal, 5)
            .frame(minWidth: Metrics.Footer.keyHeight, minHeight: Metrics.Footer.keyHeight)
            .background(palette.chip, in: RoundedRectangle(cornerRadius: Metrics.Footer.keyRadius, style: .continuous))
            .fixedSize()
    }
}

/// Mirrors pointer hover into a binding.
struct HoverState: ViewModifier {
    @Binding var isHovered: Bool

    func body(content: Content) -> some View {
        content.onHover { isHovered = $0 }
    }
}

extension View {
    func trackHover(_ isHovered: Binding<Bool>) -> some View {
        modifier(HoverState(isHovered: isHovered))
    }
}

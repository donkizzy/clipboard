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

/// Source app badge: the real app icon, or a tinted square with the app's
/// initial when the app isn't installed (or while the icon loads).
struct AppBadge: View {
    let clip: ClipSnapshot
    let size: CGFloat
    let radius: CGFloat
    let fontSize: CGFloat

    @State private var icon: NSImage?

    private var bundleID: String? { clip.source?.bundleID }

    var body: some View {
        Group {
            if let icon = icon ?? bundleID.flatMap(AppIconCache.shared.cachedIcon) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    // App icons include transparent margins; scale up slightly to match the badge size.
                    .frame(width: size * 1.2, height: size * 1.2)
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(clip.source?.tint?.color ?? Color(hex: 0x888888))
                    .frame(width: size, height: size)
                    .overlay {
                        Text(clip.sourceInitial)
                            .font(.system(size: fontSize, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .task(id: bundleID) {
            icon = nil
            guard let bundleID else { return }
            icon = await AppIconCache.shared.icon(for: bundleID)
        }
        .accessibilityHidden(true)
    }
}

/// The site's favicon on a light tile, or (until it's fetched, or if there
/// is none) the domain gradient with the domain's initial.
struct FaviconTile: View {
    let link: ClipContent.Link
    let size: CGFloat
    let radius: CGFloat
    let style: TextStyle

    @State private var favicon: NSImage?

    private static let pixelSize = 64

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let shown = favicon ?? link.faviconURL.flatMap { ImageCache.shared.cachedImage(at: $0, maxPixelSize: Self.pixelSize) }
        Group {
            if let shown {
                shape.fill(Color.white)
                    .overlay {
                        Image(nsImage: shown)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .padding(size * 0.14)
                    }
                    .overlay { shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5) }
            } else {
                shape.fill(link.resolvedArtwork.linearGradient)
                    .overlay {
                        Text(link.initial)
                            .textStyle(style)
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .task(id: link.faviconURL) {
            favicon = nil
            guard let url = link.faviconURL else { return }
            favicon = await ImageCache.shared.image(at: url, maxPixelSize: Self.pixelSize)
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
                loaded = nil
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

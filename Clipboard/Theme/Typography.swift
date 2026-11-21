import AppKit
import SwiftUI

/// A text style from the design: size, CSS weight, optional line height and
/// letter-spacing, in SF Pro or SF Mono.
///
/// SwiftUI's `Font.Weight` only has named steps, so fonts are built through
/// `NSFont` to reach in-between weights such as the design's 590. The
/// resolved `Font`, tracking and line spacing are computed once per style.
struct TextStyle: Sendable {
    let font: Font
    let tracking: CGFloat
    let lineSpacing: CGFloat

    init(
        _ size: CGFloat,
        weight cssWeight: CGFloat = 400,
        mono: Bool = false,
        lineHeight: CGFloat? = nil,
        trackingEm: CGFloat = 0
    ) {
        let weight = NSFont.Weight(cssWeight: cssWeight)
        let nsFont = mono
            ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
        font = Font(nsFont as CTFont)
        tracking = trackingEm * size
        if let lineHeight {
            let natural = nsFont.ascender - nsFont.descender + nsFont.leading
            lineSpacing = max(0, size * lineHeight - natural)
        } else {
            lineSpacing = 0
        }
    }
}

extension NSFont.Weight {
    /// Maps a CSS numeric weight (100–900) onto AppKit's −1…1 weight axis by
    /// interpolating between the named system weights.
    init(cssWeight: CGFloat) {
        let stops: [(css: CGFloat, weight: NSFont.Weight)] = [
            (100, .ultraLight), (200, .thin), (300, .light), (400, .regular),
            (500, .medium), (600, .semibold), (700, .bold), (800, .heavy), (900, .black),
        ]
        let clamped = min(max(cssWeight, 100), 900)
        guard let upperIndex = stops.firstIndex(where: { $0.css >= clamped }) else {
            self = .black
            return
        }
        let upper = stops[upperIndex]
        guard upperIndex > 0, upper.css != clamped else {
            self = upper.weight
            return
        }
        let lower = stops[upperIndex - 1]
        let fraction = (clamped - lower.css) / (upper.css - lower.css)
        self = NSFont.Weight(lower.weight.rawValue + (upper.weight.rawValue - lower.weight.rawValue) * fraction)
    }
}

extension View {
    func textStyle(_ style: TextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}

/// Every text style in the design, named after where it is used.
enum Typography {
    // Search bar
    static let searchField = TextStyle(19, lineHeight: 1.2, trackingEm: -0.01)
    static let shortcutChip = TextStyle(12, weight: 600, mono: true)

    // Filter bar
    static let filterTab = TextStyle(13, weight: 590, trackingEm: -0.01)
    static let filterCount = TextStyle(11, weight: 600, mono: true)

    // Cards
    static let cardBody = TextStyle(12.5, lineHeight: 1.45, trackingEm: -0.005)
    static let cardCode = TextStyle(12, weight: 500, mono: true, lineHeight: 1.5, trackingEm: -0.02)
    static let linkDomain = TextStyle(11.5, weight: 500)
    static let linkTitle = TextStyle(13, weight: 600, lineHeight: 1.3, trackingEm: -0.01)
    static let dimensionChip = TextStyle(10, weight: 600, mono: true)
    static let faviconInitialSmall = TextStyle(13, weight: 700)
    static let appName = TextStyle(11, weight: 500)
    static let cardTime = TextStyle(10.5, weight: 500)

    // List rows
    static let listTitle = TextStyle(13.5, weight: 590, lineHeight: 1.25, trackingEm: -0.01)
    static let listSubtitle = TextStyle(12, lineHeight: 1.2)
    static let listTime = TextStyle(11, weight: 500, mono: true)
    static let typeBadge = TextStyle(10, weight: 600)
    static let faviconInitialLarge = TextStyle(15, weight: 700)

    // Empty state
    static let emptyTitle = TextStyle(15, weight: 600, lineHeight: 1.3)
    static let emptyBody = TextStyle(13, lineHeight: 1.4)

    // Footer
    static let footerKey = TextStyle(11, weight: 600, mono: true)
    static let footerKeySymbol = TextStyle(11, weight: 600)
    static let footerLabel = TextStyle(12, weight: 500)

    // Quick Look
    static let previewText = TextStyle(15, lineHeight: 1.5)
    static let previewCode = TextStyle(12.5, weight: 500, mono: true, lineHeight: 1.55)
    static let previewLinkTitle = TextStyle(17, weight: 700, lineHeight: 1.25, trackingEm: -0.02)
    static let previewLinkURL = TextStyle(13, weight: 500, lineHeight: 1.3)
    static let previewFileTitle = TextStyle(16, weight: 700, lineHeight: 1.3)
    static let previewMeta = TextStyle(13, weight: 600)
    static let previewBadge = TextStyle(11, weight: 600)
    static let previewButton = TextStyle(14, weight: 600)
    static let previewPrimaryButton = TextStyle(14, weight: 600, trackingEm: -0.01)
    static let faviconInitialPreview = TextStyle(22, weight: 700)

    // Toast
    static let toast = TextStyle(13.5, weight: 600, trackingEm: -0.01)
}

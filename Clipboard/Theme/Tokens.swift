import SwiftUI

// MARK: - Colour tokens

/// Every colour the panel draws with, transcribed 1:1 from the design spec.
///
/// Views never hard-code colours; they read the active palette from the
/// environment (`@Environment(\.palette)`), which `RootView` resolves from the
/// colour scheme and the Reduce Transparency setting.
struct Palette: Sendable, Equatable {
    var panel: Color
    var panelBorder: Color
    var sep: Color
    var text: Color
    var textDim: Color
    var textFaint: Color
    var accent: Color
    var accentSoft: Color
    var card: Color
    var cardBorder: Color
    var cardHover: Color
    var cardSel: Color
    var cardSelBorder: Color
    var cardFoot: Color
    var chip: Color
    var chipText: Color
    var footer: Color
    var glass: Color
    var previewScrim: Color
    var previewBg: Color
    var toastBg: Color
    var toastText: Color

    /// `false` when Reduce Transparency is on and translucent surfaces have been
    /// swapped for solid ones. Views use it to skip blur materials as well.
    var isTranslucent = true

    static let success = Color(hex: 0x30D158)
    static let destructive = Color(hex: 0xFF453A)

    static let dark = Palette(
        panel: Color(30, 30, 34, 0.72),
        panelBorder: Color(255, 255, 255, 0.14),
        sep: Color(255, 255, 255, 0.09),
        text: Color(hex: 0xF5F5F7),
        textDim: Color(235, 235, 245, 0.62),
        textFaint: Color(235, 235, 245, 0.33),
        accent: Color(hex: 0x0A84FF),
        accentSoft: Color(10, 132, 255, 0.18),
        card: Color(255, 255, 255, 0.055),
        cardBorder: Color(255, 255, 255, 0.09),
        cardHover: Color(255, 255, 255, 0.1),
        cardSel: Color(10, 132, 255, 0.2),
        cardSelBorder: Color(hex: 0x0A84FF),
        cardFoot: Color(0, 0, 0, 0.14),
        chip: Color(255, 255, 255, 0.09),
        chipText: Color(235, 235, 245, 0.72),
        footer: Color(0, 0, 0, 0.12),
        glass: Color(50, 50, 54, 0.82),
        previewScrim: Color(10, 10, 14, 0.55),
        previewBg: Color(44, 44, 48, 0.92),
        toastBg: Color(50, 50, 54, 0.88),
        toastText: Color(hex: 0xF5F5F7)
    )

    static let light = Palette(
        panel: Color(250, 250, 252, 0.78),
        panelBorder: Color(0, 0, 0, 0.1),
        sep: Color(0, 0, 0, 0.08),
        text: Color(hex: 0x1D1D1F),
        textDim: Color(60, 60, 67, 0.62),
        textFaint: Color(60, 60, 67, 0.34),
        accent: Color(hex: 0x007AFF),
        accentSoft: Color(0, 122, 255, 0.12),
        card: Color(255, 255, 255, 0.7),
        cardBorder: Color(0, 0, 0, 0.07),
        cardHover: Color(0, 0, 0, 0.05),
        cardSel: Color(0, 122, 255, 0.1),
        cardSelBorder: Color(hex: 0x007AFF),
        cardFoot: Color(0, 0, 0, 0.025),
        chip: Color(0, 0, 0, 0.06),
        chipText: Color(60, 60, 67, 0.8),
        footer: Color(0, 0, 0, 0.02),
        glass: Color(255, 255, 255, 0.9),
        previewScrim: Color(220, 220, 228, 0.5),
        previewBg: Color(255, 255, 255, 0.94),
        toastBg: Color(255, 255, 255, 0.92),
        toastText: Color(hex: 0x1D1D1F)
    )

    static func resolve(_ scheme: ColorScheme, reduceTransparency: Bool) -> Palette {
        let base = scheme == .dark ? dark : light
        return reduceTransparency ? base.opaque(scheme) : base
    }

    /// Solid stand-ins for the translucent surfaces (Reduce Transparency).
    private func opaque(_ scheme: ColorScheme) -> Palette {
        var copy = self
        copy.isTranslucent = false
        switch scheme {
        case .dark:
            copy.panel = Color(30, 30, 34)
            copy.glass = Color(50, 50, 54)
            copy.previewScrim = Color(10, 10, 14, 0.8)
            copy.previewBg = Color(44, 44, 48)
            copy.toastBg = Color(50, 50, 54)
        default:
            copy.panel = Color(250, 250, 252)
            copy.glass = Color(255, 255, 255)
            copy.previewScrim = Color(220, 220, 228, 0.85)
            copy.previewBg = Color(255, 255, 255)
            copy.toastBg = Color(255, 255, 255)
        }
        return copy
    }
}

extension EnvironmentValues {
    @Entry var palette: Palette = .dark
}

// MARK: - Metrics

/// Sizes, paddings and radii from the spec. Everything uses continuous
/// (squircle) corners, matching `corner-shape: squircle` in the design.
enum Metrics {
    enum Panel {
        static let maxWidth: CGFloat = 760
        static let radius: CGFloat = 20
        static let borderWidth: CGFloat = 1 // 0.5 border + 0.5 outer ring in the design
    }

    enum SearchBar {
        static let padding = EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 18)
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 19
        static let chipRadius: CGFloat = 10
    }

    enum FilterBar {
        static let padding = EdgeInsets(top: 11, leading: 18, bottom: 11, trailing: 16)
        static let tabPadding = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        static let tabRadius: CGFloat = 8
        static let buttonSize: CGFloat = 30
        static let buttonRadius: CGFloat = 8
    }

    enum Card {
        static let width: CGFloat = 176
        static let height: CGFloat = 186
        static let radius: CGFloat = 18
        static let borderWidth: CGFloat = 1.5
        static let mediaHeight: CGFloat = 104
        static let rowSpacing: CGFloat = 12
        static let rowPadding = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        static let scrollMargin: CGFloat = 16
        static let hoverLift: CGFloat = 3
        static let pinBadgeSize: CGFloat = 20
        static let actionButtonSize: CGFloat = 24

        static var rowHeight: CGFloat { height + rowPadding.top + rowPadding.bottom }
    }

    enum List {
        static let padding: CGFloat = 8
        static let spacing: CGFloat = 2
        static let maxHeight: CGFloat = 340
        static let rowHeight: CGFloat = 58 // 1 + 9 + 38 + 9 + 1
        static let rowRadius: CGFloat = 10
        static let thumbSize: CGFloat = 38
        static let thumbRadius: CGFloat = 8
        static let scrollMargin: CGFloat = 8

        static func contentHeight(rows: Int) -> CGFloat {
            guard rows > 0 else { return 0 }
            return padding * 2 + CGFloat(rows) * rowHeight + CGFloat(rows - 1) * spacing
        }
    }

    enum Footer {
        static let padding = EdgeInsets(top: 11, leading: 18, bottom: 11, trailing: 18)
        static let spacing: CGFloat = 16
        static let keyHeight: CGFloat = 20
        static let keyRadius: CGFloat = 5
    }

    enum Preview {
        static let maxWidth: CGFloat = 440
        static let radius: CGFloat = 16
        static let imageHeight: CGFloat = 230
        static let textMaxHeight: CGFloat = 300
        static let scrimBlur: CGFloat = 9 // CSS blur(18px) ≈ Gaussian σ of 9pt
    }

    enum Toast {
        static let bottomInset: CGFloat = 64
        static let radius: CGFloat = 11
        static let visibleDuration: Duration = .milliseconds(1500)
    }
}

// MARK: - Motion

enum Motion {
    /// `cubic-bezier(.22, 1, .36, 1)` from the design, used for every "ease-out" move.
    static func easeOutQuint(_ duration: Double) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: duration)
    }

    static let panelOpen = easeOutQuint(0.42)
    static let previewOpen = easeOutQuint(0.26)
    static let toast = easeOutQuint(0.24)
    static let hover = easeOutQuint(0.18)
    static let fade = Animation.easeOut(duration: 0.18)
    static let tab = Animation.easeOut(duration: 0.16)
}

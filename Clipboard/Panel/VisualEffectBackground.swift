import AppKit
import SwiftUI

/// Behind-window vibrancy for the panel, approximating the design's
/// `backdrop-filter: blur(40px) saturate(180%)`.
///
/// AppKit doesn't expose blur radius or saturation, so the closest match is
/// the `.popover` material (which already boosts saturation), kept `.active`
/// even though our app never activates, with the palette tint layered on top
/// in SwiftUI. The rounded shape is applied with `maskImage`, which is the
/// supported way to shape an `NSVisualEffectView`.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var cornerRadius: CGFloat
    var isDark: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        configure(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        configure(view)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = material
        view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        if view.maskImage?.size.width != Self.maskSide(for: cornerRadius) {
            view.maskImage = Self.continuousMask(cornerRadius: cornerRadius)
        }
    }

    /// Continuous corners extend ~1.53× the radius along each edge, so the
    /// stretchable cap insets need to cover that much.
    private static func maskSide(for radius: CGFloat) -> CGFloat {
        (radius * 1.6).rounded(.up) * 2 + 1
    }

    /// A resizable mask image with squircle corners.
    private static func continuousMask(cornerRadius radius: CGFloat) -> NSImage {
        let side = maskSide(for: radius)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let path = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(path)
            context.setFillColor(.black)
            context.fillPath()
            return true
        }
        let inset = (side - 1) / 2
        image.capInsets = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        image.resizingMode = .stretch
        return image
    }
}

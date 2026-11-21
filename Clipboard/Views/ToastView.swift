import SwiftUI

/// "Copied to clipboard" style confirmation. Never takes clicks.
struct ToastView: View {
    @Environment(\.palette) private var palette
    let toast: Toast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.Toast.radius, style: .continuous)
        HStack(spacing: 9) {
            Circle()
                .fill(toast.style.color)
                .frame(width: 20, height: 20)
                .overlay {
                    Group {
                        if toast.style == .failed {
                            GlyphStroke(Glyph.Close(), width: 3, size: 12)
                        } else {
                            GlyphStroke(Glyph.Check(), width: 3, size: 12)
                        }
                    }
                    .foregroundStyle(.white)
                }
            Text(toast.message)
                .textStyle(Typography.toast)
                .foregroundStyle(palette.toastText)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background {
            shape.fill(palette.toastBg)
                .background(palette.isTranslucent ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear), in: shape)
        }
        .outerShadow(shape, .toast)
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("toast")
    }
}

extension Toast.Style {
    var color: Color {
        switch self {
        case .copied: Palette.success
        case .pasted: Color(hex: 0x0A84FF)
        case .deleted, .failed: Palette.destructive
        }
    }
}

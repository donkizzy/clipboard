import SwiftUI

extension Color {
    /// sRGB colour from 0–255 channels and an opacity, matching CSS `rgba()`.
    init(_ red: Int, _ green: Int, _ blue: Int, _ opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: opacity
        )
    }

    /// sRGB colour from a `0xRRGGBB` literal, matching CSS `#rrggbb`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            Int((hex >> 16) & 0xFF),
            Int((hex >> 8) & 0xFF),
            Int(hex & 0xFF),
            opacity
        )
    }
}

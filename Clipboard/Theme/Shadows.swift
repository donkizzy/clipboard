import SwiftUI

/// One CSS `box-shadow` layer: `x y blur spread color`.
struct ShadowLayer: Sendable, Equatable {
    var x: CGFloat = 0
    var y: CGFloat
    var blur: CGFloat
    var spread: CGFloat = 0
    var opacity: Double

    static let panel: [ShadowLayer] = [
        ShadowLayer(y: 32, blur: 80, spread: -12, opacity: 0.55),
        ShadowLayer(y: 12, blur: 32, spread: -8, opacity: 0.4),
    ]
    static let card = ShadowLayer(y: 1, blur: 2, opacity: 0.12)
    static let cardSelected = ShadowLayer(y: 8, blur: 24, spread: -6, opacity: 0.35)
    static let cardHover = ShadowLayer(y: 14, blur: 30, spread: -8, opacity: 0.4)
    static let preview = ShadowLayer(y: 30, blur: 70, spread: -12, opacity: 0.6)
    static let toast = ShadowLayer(y: 12, blur: 32, spread: -6, opacity: 0.5)
    static let pinBadge = ShadowLayer(y: 2, blur: 6, opacity: 0.3)
    static let glassButton = ShadowLayer(y: 2, blur: 8, opacity: 0.25)
}

/// Draws CSS-style shadows that sit *outside* a shape only.
///
/// SwiftUI's `.shadow` paints underneath the view too, so on translucent
/// surfaces (the panel, cards, Quick Look) it would darken the surface
/// itself. CSS `box-shadow` never shows through the box, so this view draws
/// the shadow from a copy of the shape inset by the CSS spread (which is how
/// negative spread works) and then erases the shape's interior.
///
/// Only spread ≤ 0 is supported, which covers every shadow in the design.
struct OuterShadow<S: InsettableShape>: View {
    let shape: S
    let layers: [ShadowLayer]

    init(_ shape: S, layers: [ShadowLayer]) {
        self.shape = shape
        self.layers = layers
    }

    init(_ shape: S, layer: ShadowLayer) {
        self.init(shape, layers: [layer])
    }

    var body: some View {
        ZStack {
            ForEach(layers.indices, id: \.self) { index in
                let layer = layers[index]
                shape
                    .inset(by: max(0, -layer.spread))
                    .fill(.black)
                    // CSS blur radius is twice the Gaussian σ that SwiftUI expects.
                    .shadow(color: .black.opacity(layer.opacity), radius: layer.blur / 2, x: layer.x, y: layer.y)
            }
            shape.fill(.black).blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

extension View {
    /// Shorthand for an `OuterShadow` behind the view.
    func outerShadow<S: InsettableShape>(_ shape: S, _ layers: [ShadowLayer]) -> some View {
        background(OuterShadow(shape, layers: layers))
    }

    func outerShadow<S: InsettableShape>(_ shape: S, _ layer: ShadowLayer) -> some View {
        background(OuterShadow(shape, layer: layer))
    }

    /// A plain SwiftUI shadow for opaque elements, converting a CSS layer.
    func cssShadow(_ layer: ShadowLayer) -> some View {
        shadow(color: .black.opacity(layer.opacity), radius: layer.blur / 2, x: layer.x, y: layer.y)
    }
}

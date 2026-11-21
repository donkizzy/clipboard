import CoreGraphics

/// Keeps the selected item visible with a margin, scrolling as little as
/// possible (the same behaviour as the design's `scrollLeft` adjustment).
///
/// SwiftUI on macOS 14 can't set a scroll offset directly, only
/// `scrollTo(id, anchor:)`, which lines the item's anchor point up with the
/// same point in the viewport. Solving that for "item edge lands `margin`
/// from the viewport edge" gives the anchor below, independent of the
/// item's position in the content.
enum ScrollIntoView {
    /// - Parameters:
    ///   - itemStart: item's leading (or top) edge in content coordinates
    ///   - itemLength: item width (or height)
    ///   - offset: current scroll offset (content coordinate at the viewport's leading edge)
    ///   - viewportLength: visible width (or height)
    ///   - margin: required gap between the item and the viewport edge
    /// - Returns: the unit anchor to pass to `scrollTo`, or `nil` if the item
    ///   is already fully visible with the margin.
    static func anchor(
        itemStart: CGFloat,
        itemLength: CGFloat,
        offset: CGFloat,
        viewportLength: CGFloat,
        margin: CGFloat
    ) -> CGFloat? {
        let slack = viewportLength - itemLength
        guard slack > 0 else { return 0 }
        if itemStart < offset + margin {
            return margin / slack
        }
        if itemStart + itemLength > offset + viewportLength - margin {
            return (viewportLength - margin - itemLength) / slack
        }
        return nil
    }
}

/// Holds live scroll geometry without triggering view updates. Writing to
/// `@State` on every scroll frame would re-evaluate the whole lazy stack.
@MainActor
final class ScrollTracker {
    var offset: CGFloat = 0
    var viewportLength: CGFloat = 0
}

/// Positions of fixed-size items laid out in a line.
struct ScrollItemMetrics: Sendable {
    var leadingPadding: CGFloat
    var length: CGFloat
    var spacing: CGFloat
    var margin: CGFloat

    func start(of index: Int) -> CGFloat {
        leadingPadding + CGFloat(index) * (length + spacing)
    }

    static let cards = ScrollItemMetrics(
        leadingPadding: Metrics.Card.rowPadding.leading,
        length: Metrics.Card.width,
        spacing: Metrics.Card.rowSpacing,
        margin: Metrics.Card.scrollMargin
    )

    static let listRows = ScrollItemMetrics(
        leadingPadding: Metrics.List.padding,
        length: Metrics.List.rowHeight,
        spacing: Metrics.List.spacing,
        margin: Metrics.List.scrollMargin
    )
}

import CoreGraphics
import Testing
@testable import Clipboard

@Suite("ScrollIntoView")
struct ScrollIntoViewTests {
    /// Applies `scrollTo(anchor:)` semantics: the item's anchor point lines up
    /// with the viewport's anchor point. Returns the resulting offset.
    private func offsetAfterScroll(itemStart: CGFloat, itemLength: CGFloat, viewport: CGFloat, anchor: CGFloat) -> CGFloat {
        itemStart + anchor * itemLength - anchor * viewport
    }

    @Test("A fully visible item doesn't scroll")
    func visible() {
        #expect(ScrollIntoView.anchor(itemStart: 206, itemLength: 176, offset: 0, viewportLength: 760, margin: 16) == nil)
    }

    @Test("An item past the trailing edge lands `margin` from it")
    func trailing() throws {
        let start = ScrollItemMetrics.cards.start(of: 4) // 18 + 4 × 188 = 770
        let anchor = try #require(ScrollIntoView.anchor(itemStart: start, itemLength: 176, offset: 0, viewportLength: 760, margin: 16))
        let offset = offsetAfterScroll(itemStart: start, itemLength: 176, viewport: 760, anchor: anchor)
        #expect(abs((start + 176) - (offset + 760) + 16) < 0.001)
    }

    @Test("An item before the leading edge lands `margin` from it")
    func leading() throws {
        let start = ScrollItemMetrics.cards.start(of: 2)
        let anchor = try #require(ScrollIntoView.anchor(itemStart: start, itemLength: 176, offset: 900, viewportLength: 760, margin: 16))
        let offset = offsetAfterScroll(itemStart: start, itemLength: 176, viewport: 760, anchor: anchor)
        #expect(abs(start - offset - 16) < 0.001)
    }

    @Test("An item inside the margin still scrolls")
    func withinMargin() {
        let anchor = ScrollIntoView.anchor(itemStart: 580, itemLength: 176, offset: 0, viewportLength: 760, margin: 16)
        #expect(anchor != nil)
    }

    @Test("List rows use an 8pt margin")
    func listRows() throws {
        let metrics = ScrollItemMetrics.listRows
        let start = metrics.start(of: 6) // 8 + 6 × 60 = 368
        #expect(start == 368)
        let anchor = try #require(ScrollIntoView.anchor(itemStart: start, itemLength: 58, offset: 0, viewportLength: 340, margin: 8))
        let offset = offsetAfterScroll(itemStart: start, itemLength: 58, viewport: 340, anchor: anchor)
        #expect(abs((start + 58) - (offset + 340) + 8) < 0.001)
    }
}

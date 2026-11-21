import SwiftUI

/// A scroll view of fixed-size items that keeps the selected item visible
/// with a margin, scrolling as little as possible.
///
/// Item positions are derived from index and the fixed metrics, so even
/// items a lazy stack hasn't realised yet can be scrolled to precisely.
struct SelectionScrollView<Content: View>: View {
    let axis: Axis
    let metrics: ScrollItemMetrics
    let selectedIndex: Int
    /// Identifies the selected item; scrolling happens when this changes.
    let selectedID: ClipSnapshot.ID?
    @ViewBuilder let content: () -> Content

    @State private var geometry = ScrollTracker()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(axis == .horizontal ? .horizontal : .vertical) {
                content()
                    .onGeometryChange(for: CGFloat.self) { [axis] proxy in
                        let frame = proxy.frame(in: .scrollView)
                        return axis == .horizontal ? -frame.minX : -frame.minY
                    } action: { offset in
                        geometry.offset = offset
                    }
            }
            .onGeometryChange(for: CGFloat.self) { [axis] proxy in
                axis == .horizontal ? proxy.size.width : proxy.size.height
            } action: { length in
                geometry.viewportLength = length
            }
            .onChange(of: selectedID) {
                scrollSelectionIntoView(proxy)
            }
        }
    }

    private func scrollSelectionIntoView(_ proxy: ScrollViewProxy) {
        guard let selectedID, geometry.viewportLength > 0 else { return }
        guard let anchor = ScrollIntoView.anchor(
            itemStart: metrics.start(of: selectedIndex),
            itemLength: metrics.length,
            offset: geometry.offset,
            viewportLength: geometry.viewportLength,
            margin: metrics.margin
        ) else { return }

        let unitPoint = axis == .horizontal
            ? UnitPoint(x: anchor, y: 0.5)
            : UnitPoint(x: 0.5, y: anchor)
        if reduceMotion {
            proxy.scrollTo(selectedID, anchor: unitPoint)
        } else {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(selectedID, anchor: unitPoint)
            }
        }
    }
}

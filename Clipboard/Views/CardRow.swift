import SwiftUI

/// Horizontally scrolling cards (the "row" layout).
struct CardRow: View {
    let clips: [ClipSnapshot]
    let selectedIndex: Int
    let now: Date
    let actions: ClipActions

    var body: some View {
        SelectionScrollView(
            axis: .horizontal,
            metrics: .cards,
            selectedIndex: selectedIndex,
            selectedID: clips.indices.contains(selectedIndex) ? clips[selectedIndex].id : nil
        ) {
            LazyHStack(spacing: Metrics.Card.rowSpacing) {
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    CardView(clip: clip, isSelected: index == selectedIndex, now: now, actions: actions)
                        .id(clip.id)
                }
            }
            .padding(Metrics.Card.rowPadding)
        }
        .frame(height: Metrics.Card.rowHeight)
        .accessibilityIdentifier("cardRow")
    }
}

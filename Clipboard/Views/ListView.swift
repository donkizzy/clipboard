import SwiftUI

/// Vertically scrolling compact rows (the "list" layout).
struct ListView: View {
    let clips: [ClipSnapshot]
    let selectedIndex: Int
    let now: Date
    let actions: ClipActions

    var body: some View {
        SelectionScrollView(
            axis: .vertical,
            metrics: .listRows,
            selectedIndex: selectedIndex,
            selectedID: clips.indices.contains(selectedIndex) ? clips[selectedIndex].id : nil
        ) {
            LazyVStack(spacing: Metrics.List.spacing) {
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    ListRowView(clip: clip, isSelected: index == selectedIndex, now: now, actions: actions)
                        .id(clip.id)
                }
            }
            .padding(Metrics.List.padding)
        }
        .frame(height: min(Metrics.List.contentHeight(rows: clips.count), Metrics.List.maxHeight))
        .accessibilityIdentifier("list")
    }
}

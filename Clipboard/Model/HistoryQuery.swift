import Foundation

/// Search + filter over history snapshots. Pure and synchronous, so it is
/// trivially unit-testable and fast enough to run on every keystroke
/// (well under a millisecond for 1,000 items, since `searchKey` is prebuilt).
struct HistoryQuery: Equatable, Sendable {
    var text = ""
    var filter: HistoryFilter = .all
    /// Float pinned items to the top. Off by default to match the design;
    /// configurable in Settings.
    var pinnedFirst = false

    /// Applies the query to `items`, which must already be newest-first.
    func apply(to items: [ClipSnapshot]) -> [ClipSnapshot] {
        let needle = SearchText.normalize(text.trimmingCharacters(in: .whitespacesAndNewlines))
        let matches = items.filter { clip in
            filter.includes(clip) && (needle.isEmpty || clip.searchKey.contains(needle))
        }
        guard pinnedFirst else { return matches }
        // Stable partition: keeps newest-first order inside each group.
        return matches.filter(\.isPinned) + matches.filter { !$0.isPinned }
    }

    /// Item count per filter tab. Counts ignore the search text, matching the design.
    static func counts(for items: [ClipSnapshot]) -> [HistoryFilter: Int] {
        var counts = Dictionary(uniqueKeysWithValues: HistoryFilter.allCases.map { ($0, 0) })
        for clip in items {
            for filter in HistoryFilter.allCases where filter.includes(clip) {
                counts[filter, default: 0] += 1
            }
        }
        return counts
    }
}

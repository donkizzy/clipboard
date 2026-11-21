import Foundation
import Testing
@testable import Clipboard

@Suite("HistoryQuery")
struct HistoryQueryTests {
    private let items = DemoSeed.snapshots(now: Date(timeIntervalSince1970: 1_795_262_400))

    private func titles(_ query: HistoryQuery) -> [String] {
        query.apply(to: items).map(\.title)
    }

    @Test("Empty query returns everything, newest first")
    func everything() {
        let result = HistoryQuery().apply(to: items)
        #expect(result.count == 12)
        #expect(result == items.sorted { $0.createdAt > $1.createdAt })
    }

    @Test("Filters by kind", arguments: [
        (HistoryFilter.text, 4), (.links, 3), (.images, 2), (.files, 3), (.pinned, 2),
    ])
    func filters(filter: HistoryFilter, expected: Int) {
        #expect(HistoryQuery(filter: filter).apply(to: items).count == expected)
    }

    @Test("Search is case-insensitive over the title")
    func titleSearch() {
        #expect(titles(HistoryQuery(text: "FRAMER")) == ["Framer Motion — layout animations"])
    }

    @Test("Search matches the body, domain and source app")
    func otherFields() {
        #expect(titles(HistoryQuery(text: "natoma")) == ["Address"])
        #expect(titles(HistoryQuery(text: "linear.app")) == ["Linear — ENG-482 Vibrancy blur perf"])
        #expect(titles(HistoryQuery(text: "vs code")) == ["debounce()"])
    }

    @Test("Search ignores diacritics and surrounding whitespace")
    func folding() {
        #expect(titles(HistoryQuery(text: "  fríday ")) == ["Ship v2.3 by Friday"])
    }

    @Test("Search and filter combine")
    func combined() {
        #expect(titles(HistoryQuery(text: "safari", filter: .links)).count == 3)
        #expect(titles(HistoryQuery(text: "safari", filter: .text)).isEmpty)
        #expect(titles(HistoryQuery(text: "debounce", filter: .pinned)) == ["debounce()"])
    }

    @Test("Pinned items stay in place unless pinned-first is on")
    func pinnedFirst() {
        #expect(titles(HistoryQuery()).firstIndex(of: "debounce()") == 4)
        let pinnedFirst = titles(HistoryQuery(pinnedFirst: true))
        #expect(Array(pinnedFirst.prefix(2)) == ["Ship v2.3 by Friday", "debounce()"])
        #expect(pinnedFirst[2] == "Framer Motion — layout animations")
    }

    @Test("Counts ignore search text")
    func counts() {
        let counts = HistoryQuery.counts(for: items)
        #expect(counts[.all] == 12)
        #expect(counts[.text] == 4)
        #expect(counts[.links] == 3)
        #expect(counts[.images] == 2)
        #expect(counts[.files] == 3)
        #expect(counts[.pinned] == 2)
    }
}

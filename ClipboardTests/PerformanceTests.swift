import XCTest
@testable import Clipboard

/// Baselines for the hot paths behind typing in the search field and
/// opening the panel with a large history.
final class PerformanceTests: XCTestCase {
    private let items = DemoSeed.snapshots(count: 5_000)

    func testSearchOverFiveThousandItems() {
        let query = HistoryQuery(text: "framer", filter: .all)
        measure {
            for _ in 0..<20 { _ = query.apply(to: items) }
        }
    }

    func testFilterCountsOverFiveThousandItems() {
        measure {
            _ = HistoryQuery.counts(for: items)
        }
    }

    func testBuildingSnapshotsForOneThousandItems() {
        measure {
            _ = DemoSeed.snapshots(count: 1_000)
        }
    }
}

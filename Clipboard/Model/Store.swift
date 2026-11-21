import Foundation
import Observation

/// The history store, as seen by the UI.
///
/// The panel only reads `snapshots` (newest first) and issues mutations. The
/// store owns persistence, dedupe and retention; implementations notify
/// observers by updating `snapshots`, which is `@Observable`-tracked.
@MainActor
protocol ClipStore: AnyObject, Observable {
    /// All items, newest first.
    var snapshots: [ClipSnapshot] { get }

    func setPinned(_ isPinned: Bool, for id: UUID)
    func delete(_ id: UUID)
}

/// A non-persistent store used for `--demo`, previews and UI tests.
@MainActor
@Observable
final class InMemoryClipStore: ClipStore {
    private(set) var snapshots: [ClipSnapshot]

    init(snapshots: [ClipSnapshot] = []) {
        self.snapshots = snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    func setPinned(_ isPinned: Bool, for id: UUID) {
        guard let index = snapshots.firstIndex(where: { $0.id == id }) else { return }
        snapshots[index].isPinned = isPinned
    }

    func delete(_ id: UUID) {
        snapshots.removeAll { $0.id == id }
    }
}

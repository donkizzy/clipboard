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
    /// Removes history; pinned items survive when `keepPinned` is true.
    func clear(keepPinned: Bool)

    /// The full content for copy/paste (snapshots only carry previews).
    func payload(for id: UUID) async -> ClipPayload?
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

    func clear(keepPinned: Bool) {
        snapshots.removeAll { !keepPinned || !$0.isPinned }
    }

    /// Simulates a capture arriving (tests and previews).
    func insertForTesting(_ snapshot: ClipSnapshot) {
        snapshots.insert(snapshot, at: 0)
    }

    func payload(for id: UUID) async -> ClipPayload? {
        guard let clip = snapshots.first(where: { $0.id == id }) else { return nil }
        switch clip.content {
        case .text(let text): return .text(text.preview)
        case .link(let link): return .link(link.url)
        // Demo images are gradients with no file; paste their title instead.
        case .image(let image): return image.imageURL.map(ClipPayload.image) ?? .text(clip.title)
        case .file(let file): return .files(file.urls)
        }
    }
}

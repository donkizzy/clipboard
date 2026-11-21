import Foundation
import Observation
import SwiftData

/// The persistent `ClipStore`: a main-actor mirror of `HistoryDatabase`.
///
/// - Reads are synchronous: the panel reads `snapshots`, an in-memory
///   array, so opening it never waits on disk.
/// - Writes are queued in order (FIFO) and run on the database actor.
///   Pin and delete are applied to `snapshots` immediately (optimistic);
///   the database's view replaces it once the queue drains, so a slow
///   write can never briefly undo a newer optimistic change.
@MainActor
@Observable
final class HistoryStore: ClipStore {
    private(set) var snapshots: [ClipSnapshot] = []
    private(set) var isLoaded = false

    /// Newest unpinned items to keep; `nil` is unlimited.
    @ObservationIgnored var retentionLimit: Int?

    /// Fetches page titles and favicons for new links; `nil` disables it.
    @ObservationIgnored var linkMetadata: LinkMetadataService?

    private typealias Operation = @Sendable (HistoryDatabase) async throws -> Void

    @ObservationIgnored private let operations: AsyncStream<Operation>.Continuation
    @ObservationIgnored private var pendingOperations = 0
    @ObservationIgnored private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private let database: Task<HistoryDatabase, Never>

    init(container: ModelContainer, images: ImageStore, retentionLimit: Int?) {
        self.retentionLimit = retentionLimit
        // On macOS 14 a ModelContext created on the main thread stays bound
        // to it, so the database actor is created off-main.
        let database = Task.detached(priority: .userInitiated) {
            HistoryDatabase(container: container, images: images)
        }
        self.database = database

        let (stream, continuation) = AsyncStream.makeStream(of: Operation.self)
        operations = continuation

        Task { [weak self] in
            let db = await database.value
            await self?.reload(from: db)
            for await operation in stream {
                do {
                    try await operation(db)
                } catch {
                    Log.store.error("History write failed: \(error.localizedDescription, privacy: .public)")
                }
                await self?.operationFinished(db)
            }
        }

        enqueue { db in
            let removed = try await db.removeOrphanedFiles()
            if removed > 0 { Log.store.info("Removed \(removed) orphaned image file(s)") }
        }
    }

    deinit {
        operations.finish()
    }

    // MARK: ClipStore

    func setPinned(_ isPinned: Bool, for id: UUID) {
        if let index = snapshots.firstIndex(where: { $0.id == id }) {
            snapshots[index].isPinned = isPinned
        }
        enqueue { try await $0.setPinned(isPinned, for: id) }
    }

    func delete(_ id: UUID) {
        snapshots.removeAll { $0.id == id }
        enqueue { try await $0.delete(id) }
    }

    // MARK: Capture and maintenance

    func ingest(_ clip: PreparedClip) {
        let limit = retentionLimit
        enqueue { [weak self] db in
            let result = try await db.ingest(clip, retentionLimit: limit)
            if case .inserted(let id) = result, let url = clip.url {
                await self?.fetchLinkMetadata(for: id, url: url)
            }
        }
    }

    /// Fetches a new link's title and favicon in the background, then
    /// stores them through the write queue like any other change.
    private func fetchLinkMetadata(for id: UUID, url: URL) {
        guard let linkMetadata else { return }
        Task { [weak self] in
            guard let metadata = await linkMetadata.fetch(url) else { return }
            self?.enqueue { db in
                try await db.updateLinkMetadata(for: id, title: metadata.title, faviconFileName: metadata.faviconFileName)
            }
        }
    }

    func clear(keepPinned: Bool) {
        snapshots.removeAll { !keepPinned || !$0.isPinned }
        enqueue { try await $0.clear(keepPinned: keepPinned) }
    }

    func applyRetention() {
        let limit = retentionLimit
        enqueue { try await $0.enforceRetention(limit: limit) }
    }

    /// Full content for copy/paste. Read directly from the database actor,
    /// not through the write queue, so a slow write never delays a paste.
    func payload(for id: UUID) async -> ClipPayload? {
        try? await database.value.payload(for: id)
    }

    /// Resolves once every queued write is applied and `snapshots` reflects
    /// the database (used by tests).
    func waitUntilIdle() async {
        if isLoaded && pendingOperations == 0 { return }
        await withCheckedContinuation { idleWaiters.append($0) }
    }

    // MARK: Private

    private func enqueue(_ operation: @escaping Operation) {
        pendingOperations += 1
        operations.yield(operation)
    }

    private func operationFinished(_ db: HistoryDatabase) async {
        pendingOperations -= 1
        guard pendingOperations == 0 else { return }
        await reload(from: db)
    }

    private func reload(from db: HistoryDatabase) async {
        do {
            let fresh = try await db.snapshots()
            // A newer write may have been queued while we were fetching.
            guard pendingOperations == 0 else { return }
            snapshots = fresh
            isLoaded = true
            let waiters = idleWaiters
            idleWaiters.removeAll()
            waiters.forEach { $0.resume() }
        } catch {
            Log.store.error("History load failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Container

extension HistoryStore {
    nonisolated static var schema: Schema { Schema([ClipItem.self]) }

    /// Opens the on-disk store. A store that can't be opened (corrupt, or
    /// from an incompatible build) is moved aside rather than crashing the
    /// app; failing that, history runs in memory for this session.
    nonisolated static func makeContainer(paths: AppPaths) -> ModelContainer {
        do {
            try paths.prepare()
        } catch {
            // Can't create our folders (permissions, disk): don't touch the
            // existing store, just run in memory for this session.
            Log.store.fault("Couldn't create the history folder: \(error.localizedDescription, privacy: .public)")
            return makeInMemoryContainer()
        }
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: paths.storeURL))
        } catch {
            Log.store.error("Couldn't open history store: \(error.localizedDescription, privacy: .public)")
        }

        quarantineStore(at: paths.storeURL)
        if let container = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: paths.storeURL)) {
            return container
        }
        Log.store.fault("Falling back to an in-memory history store")
        return makeInMemoryContainer()
    }

    nonisolated static func makeInMemoryContainer() -> ModelContainer {
        // An in-memory configuration with a valid schema can't fail.
        try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }

    private nonisolated static func quarantineStore(at url: URL) {
        let stamp = Int(Date.now.timeIntervalSince1970)
        for suffix in ["", "-shm", "-wal"] {
            let file = URL(filePath: url.path(percentEncoded: false) + suffix)
            let aside = URL(filePath: url.path(percentEncoded: false) + ".corrupt-\(stamp)" + suffix)
            try? FileManager.default.moveItem(at: file, to: aside)
        }
    }
}

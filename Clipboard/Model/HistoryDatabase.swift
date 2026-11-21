import Foundation
import SwiftData

/// Owns the SwiftData context and every write to history: dedupe,
/// retention, pin/delete and image file lifecycle. Runs on its own serial
/// executor, so none of this touches the main thread.
///
/// Every mutation returns the complete, freshly mapped history. Captures
/// are human-paced and mapping 1,000 rows takes a few milliseconds, so this
/// keeps the UI's copy trivially consistent with the database.
actor HistoryDatabase: ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor
    let images: ImageStore

    private var context: ModelContext { modelExecutor.modelContext }

    /// Create off the main thread (see `HistoryStore`): on macOS 14 a
    /// `ModelContext` created on the main thread stays bound to it.
    init(container: ModelContainer, images: ImageStore) {
        modelContainer = container
        let context = ModelContext(container)
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.images = images
    }

    // MARK: Reads

    func snapshots() throws -> [ClipSnapshot] {
        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).compactMap { $0.snapshot(images: images) }
    }

    func payload(for id: UUID) throws -> ClipPayload? {
        try item(id)?.payload(images: images)
    }

    // MARK: Writes

    enum IngestResult: Equatable, Sendable {
        case inserted(UUID)
        /// The content already existed; that item moved to the top.
        case bumped(UUID)
    }

    /// Stores a capture. A duplicate (same content hash) is moved to the top
    /// with a fresh timestamp and source instead of being copied.
    @discardableResult
    func ingest(_ clip: PreparedClip, retentionLimit: Int?) throws -> IngestResult {
        let hash = clip.contentHash
        var existing = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.contentHash == hash })
        existing.fetchLimit = 1

        if let duplicate = try context.fetch(existing).first {
            duplicate.createdAt = clip.createdAt
            duplicate.sourceName = clip.source?.name ?? duplicate.sourceName
            duplicate.sourceBundleID = clip.source?.bundleID ?? duplicate.sourceBundleID
            try context.save()
            return .bumped(duplicate.id)
        }

        let saved = try clip.image.map { try images.save($0, id: clip.id) }
        context.insert(ClipItem(clip, image: saved))
        do {
            try context.save()
        } catch {
            images.remove(fileName: saved?.fileName, thumbnailFileName: saved?.thumbnailFileName)
            throw error
        }
        try enforceRetention(limit: retentionLimit)
        return .inserted(clip.id)
    }

    /// Records a fetched page title and favicon for a link.
    func updateLinkMetadata(for id: UUID, title: String?, faviconFileName: String?) throws {
        guard let item = try item(id) else { return }
        if let title { item.linkTitle = title }
        if let faviconFileName { item.faviconFileName = faviconFileName }
        try context.save()
    }

    func setPinned(_ isPinned: Bool, for id: UUID) throws {
        guard let item = try item(id) else { return }
        item.isPinned = isPinned
        try context.save()
    }

    func delete(_ id: UUID) throws {
        guard let item = try item(id) else { return }
        try remove([item])
    }

    /// Clears history; pinned items survive unless `keepPinned` is false.
    func clear(keepPinned: Bool) throws {
        let descriptor = keepPinned
            ? FetchDescriptor<ClipItem>(predicate: #Predicate { !$0.isPinned })
            : FetchDescriptor<ClipItem>()
        try remove(context.fetch(descriptor))
    }

    /// Keeps the newest `limit` unpinned items. Pinned items never expire
    /// and don't count towards the limit. `nil` means unlimited.
    func enforceRetention(limit: Int?) throws {
        guard let limit else { return }
        var expired = FetchDescriptor<ClipItem>(
            predicate: #Predicate { !$0.isPinned },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        expired.fetchOffset = max(0, limit)
        let items = try context.fetch(expired)
        guard !items.isEmpty else { return }
        try remove(items)
        Log.store.info("Retention removed \(items.count) item(s)")
    }

    /// Deletes image files no item refers to.
    func removeOrphanedFiles() throws -> Int {
        let referenced = try context.fetch(FetchDescriptor<ClipItem>(predicate: #Predicate { $0.kindRaw == "image" }))
            .reduce(into: Set<String>()) { names, item in
                if let name = item.imageFileName { names.insert(name) }
                if let name = item.thumbnailFileName { names.insert(name) }
            }
        return images.removeOrphans(keeping: referenced)
    }

    // MARK: Private

    private func item(_ id: UUID) throws -> ClipItem? {
        var descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Deletes rows, then their files once the deletion is saved.
    private func remove(_ items: [ClipItem]) throws {
        let files = items.map { ($0.imageFileName, $0.thumbnailFileName) }
        items.forEach(context.delete)
        try context.save()
        for (fileName, thumbnailFileName) in files {
            images.remove(fileName: fileName, thumbnailFileName: thumbnailFileName)
        }
    }
}

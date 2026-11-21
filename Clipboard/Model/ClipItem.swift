import Foundation
import SwiftData

/// The persisted form of a history item.
///
/// Deliberately flat: SwiftData's support for enums with associated values
/// is fragile, so each kind's fields are optional columns and
/// `snapshot(images:)` maps them back to the typed `ClipContent`.
///
/// Long text keeps a bounded preview inline and the full string in
/// external storage, so loading the whole history to build snapshots never
/// drags megabytes of text into memory.
@Model
final class ClipItem {
    var id: UUID
    var kindRaw: String
    var title: String
    var createdAt: Date
    var isPinned: Bool
    var contentHash: String

    var sourceName: String? = nil
    var sourceBundleID: String? = nil

    // Text
    var textPreview: String? = nil
    @Attribute(.externalStorage) var fullTextData: Data? = nil
    var isCode: Bool

    // Link
    var urlString: String? = nil
    var linkTitle: String? = nil

    // Image
    var pixelWidth: Int? = nil
    var pixelHeight: Int? = nil
    var imageFormat: String? = nil
    var imageFileName: String? = nil
    var thumbnailFileName: String? = nil

    // File / folder
    var filePaths: [String]? = nil
    var byteCount: Int64? = nil
    var itemCount: Int? = nil
    var fileKindDescription: String? = nil
    var accentHex: Int? = nil

    init(_ clip: PreparedClip, image: ImageStore.Saved?) {
        id = clip.id
        kindRaw = clip.kind.rawValue
        title = clip.title
        createdAt = clip.createdAt
        isPinned = false
        contentHash = clip.contentHash
        sourceName = clip.source?.name
        sourceBundleID = clip.source?.bundleID
        isCode = clip.isCode

        if let text = clip.text {
            let preview = ClipContent.Text(text).preview
            textPreview = preview
            fullTextData = preview.count < text.count ? Data(text.utf8) : nil
        }
        urlString = clip.url?.absoluteString
        if let prepared = clip.image {
            pixelWidth = prepared.pixelWidth
            pixelHeight = prepared.pixelHeight
            imageFormat = prepared.format
            imageFileName = image?.fileName
            thumbnailFileName = image?.thumbnailFileName
        }
        if let file = clip.file {
            filePaths = file.urls.map { $0.path(percentEncoded: false) }
            byteCount = file.byteCount
            itemCount = file.itemCount
            fileKindDescription = file.kindDescription
            accentHex = file.accent.map { Int($0.hex) }
        }
    }

    var kind: ItemKind? { ItemKind(rawValue: kindRaw) }

    var source: SourceApp? {
        guard let sourceName else { return nil }
        return SourceApp(name: sourceName, bundleID: sourceBundleID, tint: SourceApp.fallbackTint(for: sourceBundleID ?? sourceName))
    }

    /// Maps the row to the immutable value the UI uses. `nil` for rows that
    /// can't be represented (unknown kind from a future version, missing URL).
    func snapshot(images: ImageStore) -> ClipSnapshot? {
        guard let kind, let content = content(kind: kind, images: images) else { return nil }
        return ClipSnapshot(id: id, title: title, content: content, source: source, createdAt: createdAt, isPinned: isPinned)
    }

    func payload(images: ImageStore) -> ClipPayload? {
        switch kind {
        case .text:
            if let fullTextData, let text = String(data: fullTextData, encoding: .utf8) { return .text(text) }
            return textPreview.map(ClipPayload.text)
        case .link:
            return urlString.flatMap(URL.init(string:)).map(ClipPayload.link)
        case .image:
            return imageFileName.map { .image(images.imageURL($0)) }
        case .folder, .doc:
            return filePaths.map { .files($0.map { URL(filePath: $0) }) }
        case nil:
            return nil
        }
    }

    private func content(kind: ItemKind, images: ImageStore) -> ClipContent? {
        switch kind {
        case .text:
            return .text(.init(textPreview ?? "", isCode: isCode))
        case .link:
            guard let url = urlString.flatMap(URL.init(string:)) else { return nil }
            return .link(.init(url: url, title: linkTitle))
        case .image:
            return .image(.init(
                pixelWidth: pixelWidth ?? 0,
                pixelHeight: pixelHeight ?? 0,
                format: imageFormat ?? "Image",
                imageURL: imageFileName.map(images.imageURL),
                thumbnailURL: thumbnailFileName.map(images.thumbnailURL)
            ))
        case .folder, .doc:
            guard let paths = filePaths, !paths.isEmpty else { return nil }
            return .file(.init(
                urls: paths.map { URL(filePath: $0, directoryHint: kind == .folder ? .isDirectory : .notDirectory) },
                isDirectory: kind == .folder,
                byteCount: byteCount,
                itemCount: itemCount,
                kindDescription: fileKindDescription ?? (kind == .folder ? "Folder" : "Document"),
                accent: accentHex.map { RGBColor(UInt32($0)) }
            ))
        }
    }
}

extension SourceApp {
    /// A stable, pleasant badge colour per app, until real icons load.
    static func fallbackTint(for seed: String) -> RGBColor {
        GradientPair.seeded(by: seed).start
    }
}

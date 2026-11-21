import Foundation

/// A captured item ready to store: classified, titled and hashed, but with
/// no files written yet. The database writes image files only after the
/// dedupe check, so re-copying an image doesn't touch the disk.
struct PreparedClip: Sendable {
    let id: UUID
    let kind: ItemKind
    let title: String
    /// SHA-256 of the kind plus canonical content, used for dedupe.
    let contentHash: String
    let createdAt: Date
    let source: SourceApp?

    var text: String?
    var isCode = false
    var url: URL?
    var image: Image?
    var file: ClipContent.File?

    struct Image: Sendable {
        var data: Data
        var typeIdentifier: String
        var pixelWidth: Int
        var pixelHeight: Int
        var format: String
    }
}

/// The full content of an item, loaded on demand for copy and paste.
enum ClipPayload: Sendable, Equatable {
    case text(String)
    case link(URL)
    case image(URL)
    case files([URL])
}

import CryptoKit
import Foundation

/// Turns a classified snapshot into a `PreparedClip`: title, metadata and
/// content hash. Pure apart from reading file metadata; runs off-main.
enum CaptureProcessor {
    static let maxTitleLength = 120

    static func prepare(
        _ classification: Classification,
        source: SourceApp?,
        now: Date = .now,
        id: UUID = UUID()
    ) -> PreparedClip? {
        switch classification {
        case .text(let string):
            var clip = PreparedClip(
                id: id, kind: .text, title: title(forText: string),
                contentHash: hash(kind: .text, string), createdAt: now, source: source
            )
            clip.text = string
            clip.isCode = CodeDetector.isCode(string, sourceBundleID: source?.bundleID)
            return clip

        case .link(let url):
            var clip = PreparedClip(
                id: id, kind: .link, title: url.displayHost ?? url.displayString,
                contentHash: hash(kind: .link, url.absoluteString), createdAt: now, source: source
            )
            clip.url = url
            return clip

        case .image(let image):
            guard let info = Thumbnailer.info(for: image.data) else { return nil }
            var clip = PreparedClip(
                id: id, kind: .image, title: "\(info.format) image",
                contentHash: hash(kind: .image, image.data), createdAt: now, source: source
            )
            clip.image = .init(
                data: image.data, typeIdentifier: image.typeIdentifier,
                pixelWidth: info.pixelWidth, pixelHeight: info.pixelHeight,
                format: info.format == "TIFF" ? "PNG" : info.format // TIFF is stored as PNG
            )
            return clip

        case .files(let urls):
            guard let file = FileInspector.inspect(urls) else { return nil }
            let paths = urls.map { $0.standardizedFileURL.path(percentEncoded: false) }
            var clip = PreparedClip(
                id: id, kind: file.isDirectory ? .folder : .doc, title: title(forFiles: urls),
                contentHash: hash(kind: file.isDirectory ? .folder : .doc, paths.joined(separator: "\n")),
                createdAt: now, source: source
            )
            clip.file = file
            return clip
        }
    }

    /// First non-empty line, whitespace-collapsed and capped.
    static func title(forText text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        let collapsed = line.replacing(#/\s+/#, with: " ")
        return collapsed.count > maxTitleLength ? String(collapsed.prefix(maxTitleLength - 1)) + "…" : collapsed
    }

    static func title(forFiles urls: [URL]) -> String {
        let name = urls.first.map { FileManager.default.displayName(atPath: $0.path(percentEncoded: false)) } ?? "File"
        return urls.count > 1 ? "\(name) and \(urls.count - 1) more" : name
    }

    static func hash(kind: ItemKind, _ string: String) -> String {
        hash(kind: kind, Data(string.utf8))
    }

    /// SHA-256 over the kind and the content, hex-encoded.
    static func hash(kind: ItemKind, _ data: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(kind.rawValue.utf8))
        hasher.update(data: Data([0]))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

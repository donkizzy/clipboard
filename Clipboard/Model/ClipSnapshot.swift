import Foundation

/// An sRGB colour stored as `0xRRGGBB`, so model values stay `Sendable`,
/// `Codable` and free of UI types.
struct RGBColor: Hashable, Sendable, Codable {
    var hex: UInt32

    init(_ hex: UInt32) {
        self.hex = hex
    }

    /// Builds a colour from HSB components in 0…1.
    init(hue: Double, saturation: Double, brightness: Double) {
        let h = (hue - hue.rounded(.down)) * 6
        let sector = Int(h) % 6
        let f = h - Double(Int(h))
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * f)
        let t = brightness * (1 - saturation * (1 - f))
        let (r, g, b): (Double, Double, Double) = switch sector {
        case 0: (brightness, t, p)
        case 1: (q, brightness, p)
        case 2: (p, brightness, t)
        case 3: (p, q, brightness)
        case 4: (t, p, brightness)
        default: (brightness, p, q)
        }
        func channel(_ value: Double) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
        hex = channel(r) << 16 | channel(g) << 8 | channel(b)
    }
}

/// A two-stop, 140° gradient used as placeholder artwork for links and images.
struct GradientPair: Hashable, Sendable, Codable {
    var start: RGBColor
    var end: RGBColor

    init(_ start: UInt32, _ end: UInt32) {
        self.start = RGBColor(start)
        self.end = RGBColor(end)
    }

    init(start: RGBColor, end: RGBColor) {
        self.start = start
        self.end = end
    }

    /// A deterministic gradient derived from a string (usually a domain), so
    /// the same site always gets the same colours across launches.
    static func seeded(by seed: String) -> GradientPair {
        let hash = StableHash.fnv1a(seed.lowercased())
        let hue = Double(hash % 360) / 360
        let shift = 0.06 + Double((hash >> 9) % 60) / 1000 // 0.06…0.12 around the wheel
        return GradientPair(
            start: RGBColor(hue: hue, saturation: 0.72, brightness: 0.96),
            end: RGBColor(hue: hue + shift, saturation: 0.62, brightness: 0.92)
        )
    }
}

/// The app an item was copied from.
struct SourceApp: Hashable, Sendable, Codable {
    var name: String
    var bundleID: String?
    /// Badge colour used when the real app icon isn't available.
    var tint: RGBColor?
}

// MARK: - Content

/// The payload of a clipboard item, by kind.
///
/// Snapshots carry only what the panel needs to draw: text is capped to a
/// preview so a 10 MB paste doesn't end up in every layout pass. The full
/// payload is loaded from the store on demand (copy, paste, Quick Look).
enum ClipContent: Hashable, Sendable {
    case text(Text)
    case link(Link)
    case image(Image)
    case file(File)

    struct Text: Hashable, Sendable {
        /// Up to `ClipContent.Text.previewLimit` characters of the original.
        var preview: String
        var isCode: Bool

        static let previewLimit = 2_000

        init(_ string: String, isCode: Bool = false) {
            preview = string.count > Self.previewLimit ? String(string.prefix(Self.previewLimit)) : string
            self.isCode = isCode
        }
    }

    struct Link: Hashable, Sendable {
        var url: URL
        /// Page title from LinkPresentation, when it has been fetched.
        var title: String?
        /// Local file URL of the cached favicon.
        var faviconURL: URL?
        /// Placeholder artwork. `nil` means "derive from the domain".
        var artwork: GradientPair?
    }

    struct Image: Hashable, Sendable {
        var pixelWidth: Int
        var pixelHeight: Int
        /// Short format name, e.g. "PNG" or "JPEG".
        var format: String
        var thumbnailURL: URL?
        /// Placeholder artwork shown until (or instead of) a thumbnail.
        var artwork: GradientPair?
    }

    struct File: Hashable, Sendable {
        var url: URL
        var isDirectory: Bool
        var byteCount: Int64?
        var itemCount: Int?
        /// Localized type name, e.g. "Numbers spreadsheet" or "PDF Document".
        var kindDescription: String
        /// Tint for the folder or page glyph, derived from the file type.
        var accent: RGBColor?
    }

    var kind: ItemKind {
        switch self {
        case .text: .text
        case .link: .link
        case .image: .image
        case .file(let file): file.isDirectory ? .folder : .doc
        }
    }
}

// MARK: - Snapshot

/// An immutable, `Sendable` view of one history item: the only model type
/// the panel's views ever see.
struct ClipSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let content: ClipContent
    let source: SourceApp?
    var createdAt: Date
    var isPinned: Bool

    /// Case- and diacritic-folded haystack for search: title, body, domain
    /// and source app name. Built once so filtering 1,000 items stays cheap.
    let searchKey: String

    init(
        id: UUID = UUID(),
        title: String,
        content: ClipContent,
        source: SourceApp?,
        createdAt: Date,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.createdAt = createdAt
        self.isPinned = isPinned
        searchKey = SearchText.normalize(Self.searchableParts(title: title, content: content, source: source)
            .joined(separator: "\n"))
    }

    var kind: ItemKind { content.kind }

    private static func searchableParts(title: String, content: ClipContent, source: SourceApp?) -> [String] {
        var parts = [title]
        switch content {
        case .text(let text):
            parts.append(text.preview)
        case .link(let link):
            parts.append(link.url.absoluteString)
            if let host = link.url.displayHost { parts.append(host) }
            if let pageTitle = link.title { parts.append(pageTitle) }
        case .image(let image):
            parts.append(image.format)
        case .file(let file):
            parts.append(file.url.path(percentEncoded: false))
            parts.append(file.kindDescription)
        }
        if let source { parts.append(source.name) }
        return parts
    }
}

// MARK: - Helpers

enum SearchText {
    /// Folds case, diacritics and width so "Resume" matches "Résumé".
    static func normalize(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}

enum StableHash {
    /// 64-bit FNV-1a. Unlike `Hasher`, it gives the same value on every launch.
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

extension URL {
    /// Host without a leading "www.", e.g. "framer.com".
    var displayHost: String? {
        guard let host = host(percentEncoded: false), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// The URL without its scheme or a trailing slash, e.g. "framer.com/motion".
    var displayString: String {
        var string = absoluteString
        for prefix in ["https://", "http://"] where string.hasPrefix(prefix) {
            string.removeFirst(prefix.count)
        }
        if string.hasPrefix("www.") { string.removeFirst(4) }
        if string.hasSuffix("/") { string.removeLast() }
        return string
    }
}

import Foundation

/// Presentation strings shared by cards, rows, Quick Look and VoiceOver.
extension ClipSnapshot {
    /// Text shown under the title in list rows.
    var subtitle: String {
        switch content {
        case .text(let text):
            text.preview.replacing(#/\s*\n\s*/#, with: " ")
        case .link(let link):
            link.url.displayString
        case .image(let image):
            "\(image.pixelWidth) × \(image.pixelHeight) · \(image.format)"
        case .file(let file):
            [file.sizeDescription, file.kindDescription].compactMap(\.self).joined(separator: " · ")
        }
    }

    /// Label for the type badge in list rows and Quick Look.
    var typeBadge: String {
        switch content {
        case .text(let text): text.isCode ? "Code" : "Text"
        case .link: "Link"
        case .image: "Image"
        case .file(let file): file.isDirectory ? "Folder" : "File"
        }
    }

    var sourceName: String { source?.name ?? "Unknown app" }

    /// First letter of the source app, for the fallback badge.
    var sourceInitial: String { String(sourceName.prefix(1)).uppercased() }

    /// VoiceOver label, e.g. "Link, Framer Motion — layout animations, from
    /// Safari, 2 minutes ago, pinned".
    func accessibilityDescription(now: Date) -> String {
        var parts = [typeBadge, title, "from \(sourceName)", RelativeTime.spoken(createdAt, now: now)]
        if isPinned { parts.append("pinned") }
        return parts.joined(separator: ", ")
    }
}

extension ClipContent.Link {
    var domain: String { url.displayHost ?? url.displayString }

    /// Letter shown on the placeholder favicon.
    var initial: String { String(domain.prefix(1)).uppercased() }

    var resolvedArtwork: GradientPair { artwork ?? .seeded(by: domain) }
}

extension ClipContent.Image {
    /// Compact dimensions for the chip on image cards, e.g. "2880×1620".
    var dimensionLabel: String { "\(pixelWidth)×\(pixelHeight)" }

    var resolvedArtwork: GradientPair {
        artwork ?? .seeded(by: "\(pixelWidth)x\(pixelHeight)\(format)")
    }
}

extension ClipContent.File {
    /// "1.2 MB" for files, "48 items" for folders, "3 items" for a multi-file copy.
    var sizeDescription: String? {
        if urls.count > 1 { return "\(urls.count) items" }
        if isDirectory {
            guard let itemCount else { return nil }
            return itemCount == 1 ? "1 item" : "\(itemCount) items"
        }
        guard let byteCount else { return nil }
        return byteCount.formatted(.byteCount(style: .file))
    }
}

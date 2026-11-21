import Foundation
import UniformTypeIdentifiers

/// What a pasteboard snapshot contains, decided by the spec's priority:
/// files → image → link → text.
enum Classification: Equatable, Sendable {
    case files([URL])
    case image(PasteboardSnapshot.ImageData)
    case link(URL)
    case text(String)
}

enum ItemClassifier {
    /// Plain/rich text types, used to judge whether an image is the primary
    /// representation or just a rendering attached to copied text.
    static let textTypes: Set<String> = [
        UTType.utf8PlainText.identifier, UTType.plainText.identifier, UTType.utf16PlainText.identifier,
        UTType.rtf.identifier, UTType.html.identifier, "NSStringPboardType",
    ]

    static func classify(_ snapshot: PasteboardSnapshot) -> Classification? {
        if !snapshot.fileURLs.isEmpty {
            return .files(snapshot.fileURLs)
        }
        if let image = snapshot.image, imageIsPrimary(in: snapshot) {
            return .image(image)
        }
        guard let string = snapshot.string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // An image that lost to text, but the text was empty after all.
            return snapshot.image.map(Classification.image)
        }
        if let url = linkURL(in: string) {
            return .link(url)
        }
        return .text(string)
    }

    /// Apps like Numbers, Excel and Word put a picture of the selection on
    /// the pasteboard alongside the text. Types are ordered by the owner's
    /// preference, so the image only wins if it comes before any text type
    /// (screenshots and "Copy Image" list the image first).
    static func imageIsPrimary(in snapshot: PasteboardSnapshot) -> Bool {
        guard let image = snapshot.image else { return false }
        guard snapshot.string != nil else { return true }
        let imageIndex = snapshot.types.firstIndex(of: image.typeIdentifier) ?? Int.max
        let textIndex = snapshot.types.firstIndex(where: textTypes.contains) ?? Int.max
        return imageIndex < textIndex
    }

    /// The URL if `string` is exactly one http(s) URL with a dotted host.
    static func linkURL(in string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = components.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix("."),
              let url = components.url
        else { return nil }
        return url
    }
}

/// Decides whether copied text is code, for monospaced rendering.
///
/// Text from an editor or terminal is always code. Otherwise a small score
/// over syntax signals must reach 2, so a single stray semicolon or
/// brace in prose doesn't trip it.
enum CodeDetector {
    static let codeAppBundleIDs: Set<String> = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.apple.dt.Xcode",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "dev.zed.Zed",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "com.sublimetext.4",
        "com.panic.Nova",
    ]

    // Regex isn't Sendable; these are immutable after initialisation.
    nonisolated(unsafe) private static let keywordPattern = /^\s*(func|function|def|class|struct|enum|const|let|var|import|return|if\s*\(|for\s*\(|while\s*\(|#include|#import|public|private|package|SELECT|select)\b/
    nonisolated(unsafe) private static let arrowPattern = /\)\s*=>|=>\s*\{|->\s*\w/

    static func isCode(_ text: String, sourceBundleID: String?) -> Bool {
        if let sourceBundleID, codeAppBundleIDs.contains(sourceBundleID) { return true }
        return score(text) >= 2
    }

    static func score(_ text: String) -> Int {
        let sample = text.prefix(4_000)
        let trimmed = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = sample.split(separator: "\n", omittingEmptySubsequences: true)
        var score = 0

        if sample.contains(arrowPattern) { score += 2 }
        if sample.contains("{") && sample.contains("}") { score += 1 }
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            score += 1
        }

        let semicolonLines = lines.count { $0.trimmingCharacters(in: .whitespaces).hasSuffix(";") }
        score += min(semicolonLines, 2)

        // Indented lines, excluding nested list items ("  - item"), which are prose.
        let indentedLines = lines.count { line in
            guard line.hasPrefix("  ") || line.hasPrefix("\t") else { return false }
            let content = line.drop { $0 == " " || $0 == "\t" }
            return !(content.hasPrefix("- ") || content.hasPrefix("* ") || content.hasPrefix("• "))
        }
        if lines.count > 1 && indentedLines >= 2 { score += 2 }

        if lines.contains(where: { $0.contains(keywordPattern) }) { score += 1 }
        return score
    }
}

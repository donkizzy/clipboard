import AppKit
import UniformTypeIdentifiers

/// An immutable, `Sendable` copy of the parts of the pasteboard that capture
/// cares about, read in one pass so classification never touches AppKit.
struct PasteboardSnapshot: Sendable, Equatable {
    var changeCount: Int
    /// Types of the first pasteboard item, in the owner's order of preference
    /// (highest fidelity first).
    var types: [String]
    var string: String?
    var fileURLs: [URL] = []
    var image: ImageData?
    /// Bundle ID from the `org.nspasteboard.source` marker, if the copying app set it.
    var sourceBundleID: String?

    struct ImageData: Sendable, Equatable {
        var data: Data
        var typeIdentifier: String
    }
}

/// Reads `NSPasteboard` into a `PasteboardSnapshot`. Safe to call off the
/// main thread; `NSPasteboard` reads are thread-safe.
enum PasteboardReader {
    static let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")

    /// Image types, in the priority order from the spec.
    static let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff, NSPasteboard.PasteboardType(UTType.jpeg.identifier)]

    /// The first item's types, read without touching any data. Used for the
    /// privacy check, which must run before contents are read.
    static func types(of pasteboard: NSPasteboard) -> [String] {
        let itemTypes = pasteboard.pasteboardItems?.first?.types ?? pasteboard.types ?? []
        return itemTypes.map(\.rawValue)
    }

    /// Reads the contents. `maxImageBytes` guards against pathological
    /// multi-hundred-megabyte images.
    static func read(_ pasteboard: NSPasteboard, types: [String], maxImageBytes: Int = 64 << 20) -> PasteboardSnapshot {
        var snapshot = PasteboardSnapshot(changeCount: pasteboard.changeCount, types: types)
        let available = Set(pasteboard.types?.map(\.rawValue) ?? types)

        if available.contains(NSPasteboard.PasteboardType.fileURL.rawValue) {
            let urls = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL]
            snapshot.fileURLs = urls ?? []
        }

        for type in imageTypes where available.contains(type.rawValue) {
            if let data = pasteboard.data(forType: type), data.count <= maxImageBytes {
                snapshot.image = .init(data: data, typeIdentifier: type.rawValue)
            }
            break
        }

        snapshot.string = pasteboard.string(forType: .string)
        snapshot.sourceBundleID = pasteboard.string(forType: sourceType)
        return snapshot
    }
}

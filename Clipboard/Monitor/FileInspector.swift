import Foundation
import UniformTypeIdentifiers

/// Reads file metadata for copied files and folders (off the main thread).
enum FileInspector {
    static func inspect(_ urls: [URL], fileManager: FileManager = .default) -> ClipContent.File? {
        guard let first = urls.first else { return nil }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .totalFileSizeKey, .contentTypeKey, .isPackageKey]
        let values = try? first.resourceValues(forKeys: keys)

        // Packages (.app, .numbers, .key…) are directories on disk but files to users.
        let isDirectory = (values?.isDirectory ?? first.hasDirectoryPath) && !(values?.isPackage ?? false)
        let type = values?.contentType ?? UTType(filenameExtension: first.pathExtension)

        var itemCount: Int?
        var byteCount: Int64?
        if isDirectory {
            itemCount = (try? fileManager.contentsOfDirectory(atPath: first.path(percentEncoded: false)))?
                .count { !$0.hasPrefix(".") }
        } else {
            byteCount = (values?.totalFileSize ?? values?.fileSize).map(Int64.init)
        }

        return ClipContent.File(
            urls: urls,
            isDirectory: isDirectory,
            byteCount: byteCount,
            itemCount: itemCount,
            kindDescription: isDirectory ? "Folder" : (type?.localizedDescription ?? "Document"),
            accent: isDirectory ? nil : accent(for: type)
        )
    }

    /// Glyph tint by file type, echoing the colours in the design
    /// (spreadsheet green, PDF red); `nil` falls back to the accent colour.
    static func accent(for type: UTType?) -> RGBColor? {
        guard let type else { return nil }
        let table: [(UTType, UInt32)] = [
            (.pdf, 0xFF453A),
            (.spreadsheet, 0x30D158),
            (.presentation, 0xFF9F0A),
            (.image, 0xBF5AF2),
            (.audiovisualContent, 0xFF375F),
            (.archive, 0x8E8E93),
            (.sourceCode, 0x64D2FF),
            (.script, 0x64D2FF),
            (.text, 0x0A84FF),
        ]
        return table.first { type.conforms(to: $0.0) }.map { RGBColor($0.1) }
    }
}

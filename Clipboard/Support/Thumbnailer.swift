import Foundation
import ImageIO
import UniformTypeIdentifiers

/// ImageIO helpers: image metadata, thumbnails and PNG encoding.
/// Pure and thread-safe; always called off the main thread.
enum Thumbnailer {
    /// Card thumbnails are 176pt wide; 352px covers Retina.
    static let thumbnailWidth = 352
    /// Cap for very tall images, so a long screenshot doesn't make a huge "thumbnail".
    static let maxThumbnailPixels = 1_056

    struct Info: Equatable, Sendable {
        var pixelWidth: Int
        var pixelHeight: Int
        var format: String
    }

    /// Dimensions and format from the image header, without decoding pixels.
    static func info(for data: Data) -> Info? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              var width = properties[kCGImagePropertyPixelWidth] as? Int,
              var height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        // EXIF orientations 5–8 rotate by 90°.
        if let orientation = properties[kCGImagePropertyOrientation] as? Int, (5...8).contains(orientation) {
            swap(&width, &height)
        }
        let type = (CGImageSourceGetType(source) as String?).flatMap(UTType.init)
        return Info(pixelWidth: width, pixelHeight: height, format: formatName(for: type))
    }

    static func formatName(for type: UTType?) -> String {
        guard let type else { return "Image" }
        if type.conforms(to: .png) { return "PNG" }
        if type.conforms(to: .jpeg) { return "JPEG" }
        if type.conforms(to: .tiff) { return "TIFF" }
        if type.conforms(to: .heic) { return "HEIC" }
        if type.conforms(to: .gif) { return "GIF" }
        return type.preferredFilenameExtension?.uppercased() ?? "Image"
    }

    /// A 352px-wide thumbnail, orientation applied, encoded as PNG.
    static func thumbnailPNG(from data: Data, pixelWidth: Int, pixelHeight: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), pixelWidth > 0 else { return nil }
        let aspect = Double(max(pixelWidth, pixelHeight)) / Double(pixelWidth)
        let maxPixelSize = min(Int((Double(thumbnailWidth) * aspect).rounded()), maxThumbnailPixels)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: false,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return pngData(thumbnail)
    }

    /// Re-encodes any ImageIO-readable data as PNG (used for TIFF, which is huge).
    static func pngData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return pngData(image)
    }

    static func pngData(_ image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}

/// Image files for history items: originals in `images/`, thumbnails in
/// `thumbnails/`, both named by item ID.
struct ImageStore: Sendable {
    let paths: AppPaths

    struct Saved: Sendable {
        var fileName: String
        var thumbnailFileName: String?
    }

    func save(_ image: PreparedClip.Image, id: UUID) throws -> Saved {
        let original: Data
        let fileExtension: String
        let type = UTType(image.typeIdentifier)
        if type?.conforms(to: .png) == true {
            (original, fileExtension) = (image.data, "png")
        } else if type?.conforms(to: .jpeg) == true {
            (original, fileExtension) = (image.data, "jpg") // re-encoding a JPEG as PNG only bloats it
        } else {
            (original, fileExtension) = (Thumbnailer.pngData(from: image.data) ?? image.data, "png")
        }

        let fileName = "\(id.uuidString).\(fileExtension)"
        try original.write(to: paths.imagesDirectory.appending(path: fileName), options: .atomic)

        var thumbnailName: String?
        if let thumbnail = Thumbnailer.thumbnailPNG(from: image.data, pixelWidth: image.pixelWidth, pixelHeight: image.pixelHeight) {
            let name = "\(id.uuidString).png"
            try thumbnail.write(to: paths.thumbnailsDirectory.appending(path: name), options: .atomic)
            thumbnailName = name
        }
        return Saved(fileName: fileName, thumbnailFileName: thumbnailName)
    }

    func imageURL(_ fileName: String) -> URL { paths.imagesDirectory.appending(path: fileName) }
    func thumbnailURL(_ fileName: String) -> URL { paths.thumbnailsDirectory.appending(path: fileName) }

    func remove(fileName: String?, thumbnailFileName: String?) {
        let fileManager = FileManager.default
        if let fileName { try? fileManager.removeItem(at: imageURL(fileName)) }
        if let thumbnailFileName { try? fileManager.removeItem(at: thumbnailURL(thumbnailFileName)) }
    }

    /// Deletes files no item refers to (e.g. after a crash between writing
    /// a file and saving its row).
    func removeOrphans(keeping referenced: Set<String>) -> Int {
        let fileManager = FileManager.default
        var removed = 0
        for directory in [paths.imagesDirectory, paths.thumbnailsDirectory] {
            let names = (try? fileManager.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
            for name in names where !referenced.contains(name) {
                if (try? fileManager.removeItem(at: directory.appending(path: name))) != nil { removed += 1 }
            }
        }
        return removed
    }
}

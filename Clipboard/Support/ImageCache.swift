import AppKit
import ImageIO

/// Decoded thumbnails and previews, keyed by file URL and decode size.
///
/// Decoding happens off the main thread, downsampled to the size it's shown
/// at; cache hits are synchronous, so a card scrolling back into view shows
/// its image on the first frame. Capped by decoded bytes, not count.
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 128 << 20 // 128 MB of decoded pixels
        return cache
    }()

    func cachedImage(at url: URL, maxPixelSize: Int) -> NSImage? {
        cache.object(forKey: key(url, maxPixelSize))
    }

    func image(at url: URL, maxPixelSize: Int) async -> NSImage? {
        if let cached = cachedImage(at: url, maxPixelSize: maxPixelSize) { return cached }
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.decode(url, maxPixelSize: maxPixelSize)
        }.value
        guard let decoded else { return nil }
        let image = NSImage(cgImage: decoded, size: .zero)
        cache.setObject(image, forKey: key(url, maxPixelSize), cost: decoded.bytesPerRow * decoded.height)
        return image
    }

    private func key(_ url: URL, _ maxPixelSize: Int) -> NSString {
        "\(maxPixelSize)|\(url.path(percentEncoded: false))" as NSString
    }

    private nonisolated static func decode(_ url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

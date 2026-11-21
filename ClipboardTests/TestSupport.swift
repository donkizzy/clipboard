import AppKit
import Foundation
@testable import Clipboard

enum TestSupport {
    /// A solid-colour PNG of the given size.
    static func pngData(width: Int = 40, height: Int = 30, gray: CGFloat = 0.5) -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: gray, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return Thumbnailer.pngData(context.makeImage()!)!
    }

    /// A fresh, empty Application Support-like directory.
    static func temporaryPaths() throws -> AppPaths {
        let paths = AppPaths(root: FileManager.default.temporaryDirectory
            .appending(path: "ClipboardTests-\(UUID().uuidString)", directoryHint: .isDirectory))
        try paths.prepare()
        return paths
    }

    static func files(in directory: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
    }

    static let safari = SourceApp(name: "Safari", bundleID: "com.apple.Safari")

    static func textClip(_ text: String, at date: Date = .now, source: SourceApp? = safari) -> PreparedClip {
        CaptureProcessor.prepare(.text(text), source: source, now: date)!
    }
}

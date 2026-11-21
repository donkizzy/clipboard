import AppKit
import CryptoKit
import LinkPresentation
import UniformTypeIdentifiers

/// Fetches page titles and favicons for copied links with LinkPresentation.
///
/// Favicons are stored once per host (`favicons/<sha256(host)>.png`,
/// downsampled to 64px), so a hundred copied GitHub links share one file.
@MainActor
final class LinkMetadataService {
    struct Metadata: Sendable, Equatable {
        var title: String?
        var faviconFileName: String?
    }

    private let images: ImageStore
    private let isEnabled: () -> Bool
    private var inFlight: Set<URL> = []

    nonisolated static let timeout: TimeInterval = 10
    nonisolated static let faviconPixels = 64

    init(images: ImageStore, isEnabled: @escaping () -> Bool) {
        self.images = images
        self.isEnabled = isEnabled
    }

    /// Returns `nil` when fetching is off, not allowed for this URL, or failed.
    func fetch(_ url: URL) async -> Metadata? {
        guard isEnabled(), LinkPreviewPolicy.allowsFetching(url), !inFlight.contains(url) else { return nil }
        inFlight.insert(url)
        defer { inFlight.remove(url) }

        let provider = LPMetadataProvider()
        provider.timeout = Self.timeout
        let metadata: LPLinkMetadata
        do {
            metadata = try await provider.startFetchingMetadata(for: url)
        } catch {
            Log.capture.info("Link preview unavailable: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        var faviconFileName: String?
        if let host = url.displayHost, let iconProvider = metadata.iconProvider ?? metadata.imageProvider {
            faviconFileName = await saveFavicon(from: iconProvider, host: host)
        }
        return Metadata(title: title, faviconFileName: faviconFileName)
    }

    private func saveFavicon(from provider: NSItemProvider, host: String) async -> String? {
        let fileName = CaptureProcessor.hash(kind: .link, host) + ".png"
        let destination = images.faviconURL(fileName)
        if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) { return fileName }

        guard let data = await Self.loadImageData(from: provider) else { return nil }
        let saved = await Task.detached(priority: .utility) {
            guard let info = Thumbnailer.info(for: data),
                  let png = Thumbnailer.downsampledPNG(from: data, maxPixelSize: min(Self.faviconPixels, max(info.pixelWidth, info.pixelHeight)))
            else { return false }
            return (try? png.write(to: destination, options: .atomic)) != nil
        }.value
        return saved ? fileName : nil
    }

    private static func loadImageData(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}

/// Which links may be fetched. Fetching a URL is a network request on the
/// user's behalf, so intranet and loopback hosts are never contacted.
enum LinkPreviewPolicy {
    static func allowsFetching(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty
        else { return false }
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") || host.hasSuffix(".internal") {
            return false
        }
        if !host.contains(".") { return false } // single-label intranet names
        return !isPrivateIPv4(host) && !host.contains(":") // IPv6 literals are almost always local
    }

    private static func isPrivateIPv4(_ host: String) -> Bool {
        let octets = host.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }
        switch (octets[0], octets[1]) {
        case (10, _), (127, _), (0, _): return true
        case (172, 16...31), (192, 168), (169, 254), (100, 64...127): return true
        default: return false
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

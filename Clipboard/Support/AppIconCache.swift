import AppKit

/// App icons by bundle ID, for the source badges on cards and rows.
///
/// Icons are rendered off the main thread at badge size (2× the largest
/// badge), then cached for the session. Uninstalled apps cache as a miss,
/// so the coloured-initial fallback doesn't retry on every render.
@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private nonisolated static let pixelSize = 64
    private var icons: [String: NSImage] = [:]
    private var misses: Set<String> = []
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    func cachedIcon(for bundleID: String) -> NSImage? {
        icons[bundleID]
    }

    func icon(for bundleID: String) async -> NSImage? {
        if let icon = icons[bundleID] { return icon }
        if misses.contains(bundleID) { return nil }
        if let task = inFlight[bundleID] { return await task.value }

        let task = Task<NSImage?, Never> {
            let rendered = await Task.detached(priority: .utility) { Self.render(bundleID) }.value
            return rendered.map { NSImage(cgImage: $0, size: NSSize(width: 32, height: 32)) }
        }
        inFlight[bundleID] = task
        let icon = await task.value
        inFlight[bundleID] = nil
        if let icon { icons[bundleID] = icon } else { misses.insert(bundleID) }
        return icon
    }

    private nonisolated static func render(_ bundleID: String) -> CGImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        var rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        return icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

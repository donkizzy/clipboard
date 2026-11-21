import Foundation

/// On-disk locations, all under `~/Library/Application Support/Clipboard/`.
struct AppPaths: Sendable {
    let root: URL

    var storeURL: URL { root.appending(path: "History.store") }
    var imagesDirectory: URL { root.appending(path: "images", directoryHint: .isDirectory) }
    var thumbnailsDirectory: URL { root.appending(path: "thumbnails", directoryHint: .isDirectory) }
    var faviconsDirectory: URL { root.appending(path: "favicons", directoryHint: .isDirectory) }

    static let standard = AppPaths(
        root: URL.applicationSupportDirectory.appending(path: "Clipboard", directoryHint: .isDirectory)
    )

    /// Creates the directories if needed.
    func prepare() throws {
        let fileManager = FileManager.default
        for directory in [root, imagesDirectory, thumbnailsDirectory, faviconsDirectory] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}

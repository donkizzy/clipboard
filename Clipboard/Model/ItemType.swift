import Foundation

/// What a clipboard item holds. The raw values are persisted, so don't rename them.
enum ItemKind: String, Codable, Sendable, CaseIterable {
    case text
    case link
    case image
    case folder
    case doc

    var isFile: Bool { self == .folder || self == .doc }
}

/// The filter tabs, in display order. `⌘1…⌘6` map onto `allCases` by index.
enum HistoryFilter: Int, CaseIterable, Identifiable, Sendable {
    case all
    case text
    case links
    case images
    case files
    case pinned

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .text: "Text"
        case .links: "Links"
        case .images: "Images"
        case .files: "Files"
        case .pinned: "Pinned"
        }
    }

    func includes(_ clip: ClipSnapshot) -> Bool {
        switch self {
        case .all: true
        case .text: clip.kind == .text
        case .links: clip.kind == .link
        case .images: clip.kind == .image
        case .files: clip.kind.isFile
        case .pinned: clip.isPinned
        }
    }
}

/// How the panel lays out results.
enum PanelLayout: String, CaseIterable, Sendable {
    /// Horizontally scrolling cards.
    case row
    /// Vertically scrolling compact rows.
    case list

    var toggled: PanelLayout { self == .row ? .list : .row }
}

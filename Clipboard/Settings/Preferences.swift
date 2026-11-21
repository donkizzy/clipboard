import Foundation
import Observation

/// Appearance setting: follow the system (default) or force a scheme.
enum AppearancePreference: String, CaseIterable, Sendable {
    case system
    case dark
    case light
}

/// User preferences, persisted to `UserDefaults`.
@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let appearance = "appearance"
        static let layout = "layout"
        static let pinnedOnTop = "pinnedOnTop"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var appearance: AppearancePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    var layout: PanelLayout {
        didSet { defaults.set(layout.rawValue, forKey: Key.layout) }
    }

    var pinnedOnTop: Bool {
        didSet { defaults.set(pinnedOnTop, forKey: Key.pinnedOnTop) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Key.appearance).flatMap(AppearancePreference.init) ?? .system
        layout = defaults.string(forKey: Key.layout).flatMap(PanelLayout.init) ?? .row
        pinnedOnTop = defaults.bool(forKey: Key.pinnedOnTop)
    }
}

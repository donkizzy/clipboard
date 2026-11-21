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
        static let historyLimit = "historyLimit"
        static let ignoredBundleIDs = "ignoredBundleIDs"
        static let ignoresConcealed = "ignoresConcealed"
        static let fetchesLinkPreviews = "fetchesLinkPreviews"
    }

    /// History limit choices offered in Settings; `nil` is unlimited.
    static let historyLimitOptions: [Int?] = [100, 250, 500, 1_000, nil]
    static let defaultHistoryLimit = 500

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

    /// Newest unpinned items to keep; `nil` means unlimited.
    var historyLimit: Int? {
        didSet { defaults.set(historyLimit ?? 0, forKey: Key.historyLimit) }
    }

    /// Apps whose copies are never recorded.
    var ignoredBundleIDs: Set<String> {
        didSet { defaults.set(ignoredBundleIDs.sorted(), forKey: Key.ignoredBundleIDs) }
    }

    /// Skip items marked concealed (passwords). Locked on by default.
    var ignoresConcealed: Bool {
        didSet { defaults.set(ignoresConcealed, forKey: Key.ignoresConcealed) }
    }

    /// Fetch page titles and favicons for copied links (network access).
    var fetchesLinkPreviews: Bool {
        didSet { defaults.set(fetchesLinkPreviews, forKey: Key.fetchesLinkPreviews) }
    }

    /// Temporarily stop recording (menu bar "Pause Capture"). Not persisted:
    /// capture always resumes on relaunch, so it can't be forgotten off.
    var isCapturePaused = false

    var capturePolicy: CapturePolicy {
        CapturePolicy(isPaused: isCapturePaused, ignoresConcealed: ignoresConcealed, ignoredBundleIDs: ignoredBundleIDs)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Key.appearance).flatMap(AppearancePreference.init) ?? .system
        layout = defaults.string(forKey: Key.layout).flatMap(PanelLayout.init) ?? .row
        pinnedOnTop = defaults.bool(forKey: Key.pinnedOnTop)
        if defaults.object(forKey: Key.historyLimit) == nil {
            historyLimit = Self.defaultHistoryLimit
        } else {
            let stored = defaults.integer(forKey: Key.historyLimit)
            historyLimit = stored > 0 ? stored : nil
        }
        ignoredBundleIDs = (defaults.stringArray(forKey: Key.ignoredBundleIDs)).map(Set.init)
            ?? CapturePolicy.defaultIgnoredBundleIDs
        ignoresConcealed = defaults.object(forKey: Key.ignoresConcealed) as? Bool ?? true
        fetchesLinkPreviews = defaults.object(forKey: Key.fetchesLinkPreviews) as? Bool ?? true
    }
}

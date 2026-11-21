import AppKit
import os

/// Polls the general pasteboard and turns new contents into `PreparedClip`s.
///
/// macOS has no pasteboard-change notification, so polling `changeCount`
/// is the standard approach. It's a single integer read every 0.5s, with
/// timer tolerance so the system can coalesce wake-ups. Everything,
/// including reading and classifying, runs on this actor, off the main thread.
actor PasteboardMonitor {
    typealias Sink = @Sendable (PreparedClip) async -> Void

    static let pollInterval: Duration = .milliseconds(500)

    private let pasteboard: NSPasteboard
    private let frontmostApp: OSAllocatedUnfairLock<SourceApp?>
    private let ownWrites: OwnPasteboardWrites
    private let sink: Sink
    private var policy: CapturePolicy
    private var lastChangeCount: Int?
    private var pollTask: Task<Void, Never>?

    init(
        pasteboardName: NSPasteboard.Name = .general,
        frontmostApp: OSAllocatedUnfairLock<SourceApp?>,
        ownWrites: OwnPasteboardWrites,
        policy: CapturePolicy,
        sink: @escaping Sink
    ) {
        pasteboard = NSPasteboard(name: pasteboardName)
        self.frontmostApp = frontmostApp
        self.ownWrites = ownWrites
        self.policy = policy
        self.sink = sink
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: Self.pollInterval, tolerance: .milliseconds(150))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func update(policy: CapturePolicy) {
        self.policy = policy
    }

    /// Checks for a change and captures it. Internal so tests can drive it.
    func poll() async {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        if ownWrites.consume(changeCount) { return }

        // Privacy first: decide from the type list alone, before any
        // contents (possibly a password) are read into memory.
        let types = PasteboardReader.types(of: pasteboard)
        guard !types.isEmpty else { return }
        let source = resolveSource(markedBundleID: pasteboard.string(forType: PasteboardReader.sourceType))
        if let reason = PrivacyFilter.skipReason(types: types, sourceBundleID: source?.bundleID, policy: policy) {
            Log.capture.debug("Skipped pasteboard change: \(String(describing: reason), privacy: .public)")
            return
        }

        let snapshot = PasteboardReader.read(pasteboard, types: types)
        guard let classification = ItemClassifier.classify(snapshot),
              let clip = CaptureProcessor.prepare(classification, source: source)
        else { return }
        await sink(clip)
    }

    /// Prefers the app named by the `org.nspasteboard.source` marker, which
    /// is exact; otherwise the frontmost app at the time of the change.
    private func resolveSource(markedBundleID: String?) -> SourceApp? {
        if let markedBundleID, let app = SourceApp(bundleID: markedBundleID) {
            return app
        }
        return frontmostApp.withLock { $0 }
    }
}

/// Change counts produced by our own pasteboard writes, so the monitor can
/// ignore them. Lock-based rather than actor-based so the writer can
/// register a change synchronously, before the monitor could poll it.
final class OwnPasteboardWrites: Sendable {
    private let changeCounts = OSAllocatedUnfairLock<Set<Int>>(initialState: [])

    func register(_ changeCount: Int) {
        changeCounts.withLock { _ = $0.insert(changeCount) }
    }

    /// True (and forgets it) if `changeCount` was ours.
    func consume(_ changeCount: Int) -> Bool {
        changeCounts.withLock { $0.remove(changeCount) != nil }
    }
}

/// Tracks the frontmost app (ignoring ourselves) for source attribution.
@MainActor
final class FrontmostAppTracker {
    /// Readable from any thread.
    let current = OSAllocatedUnfairLock<SourceApp?>(initialState: nil)
    private var observer: NSObjectProtocol?

    func start() {
        update(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let source = app.flatMap(SourceApp.init(runningApplication:))
            MainActor.assumeIsolated { self?.store(source) }
        }
    }

    private func update(_ app: NSRunningApplication?) {
        store(app.flatMap(SourceApp.init(runningApplication:)))
    }

    private func store(_ source: SourceApp?) {
        guard let source else { return }
        current.withLock { $0 = source }
    }
}

extension SourceApp {
    init?(runningApplication app: NSRunningApplication) {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let name = app.localizedName
        else { return nil }
        self.init(name: name, bundleID: app.bundleIdentifier, tint: Self.fallbackTint(for: app.bundleIdentifier ?? name))
    }

    /// Looks up an installed app's display name by bundle ID.
    init?(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path(percentEncoded: false))
        let trimmed = name.hasSuffix(".app") ? String(name.dropLast(4)) : name
        self.init(name: trimmed, bundleID: bundleID, tint: Self.fallbackTint(for: bundleID))
    }
}

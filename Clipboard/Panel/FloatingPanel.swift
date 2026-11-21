import AppKit

/// A borderless, non-activating floating panel, like Spotlight.
///
/// Non-activating means the app the user was typing in stays frontmost
/// while the panel takes keyboard focus, which is what makes paste-back work
/// without juggling activation.
///
/// The window is larger than the visible panel: the margin gives the SwiftUI
/// drop shadow room to render. Clicks that land in that margin (on the shadow)
/// count as "outside" and dismiss the panel.
final class FloatingPanel: NSPanel {
    /// The visible panel's rect in window coordinates, kept up to date by SwiftUI.
    var panelRect: NSRect = .zero

    /// Called for clicks in the transparent margin around the panel.
    var onClickOutsidePanel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false // drawn in SwiftUI to match the spec
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = false
        setAccessibilityIdentifier("clipboardPanel")
        setAccessibilityLabel("Clipboard history")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown,
           !panelRect.isEmpty,
           !panelRect.contains(event.locationInWindow) {
            onClickOutsidePanel?()
            return
        }
        super.sendEvent(event)
    }
}

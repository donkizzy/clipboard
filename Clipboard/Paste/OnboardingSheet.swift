import AppKit
import SwiftUI

/// Explains, once, why paste-back needs Accessibility, and links to System
/// Settings. Closes itself as soon as the permission is granted.
@MainActor
final class AccessibilityOnboarding {
    private static let hasShownKey = "hasShownAccessibilityOnboarding"

    private let defaults: UserDefaults
    private var window: NSWindow?
    private let state = OnboardingState()
    private var pollTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Shows the sheet the first time paste-back is attempted without permission.
    func presentIfNeeded() {
        guard !AccessibilityPermission.isGranted, !defaults.bool(forKey: Self.hasShownKey) else { return }
        present()
    }

    /// Shows the sheet unconditionally (e.g. from Settings).
    func present() {
        defaults.set(true, forKey: Self.hasShownKey)
        state.isGranted = AccessibilityPermission.isGranted

        let window = window ?? makeWindow()
        self.window = window
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        startPolling()
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(
            state: state,
            onOpenSettings: {
                AccessibilityPermission.requestWithSystemPrompt()
                AccessibilityPermission.openSystemSettings()
            },
            onDismiss: { [weak self] in self?.close() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.title = "Allow Clipboard to Paste"
        return window
    }

    /// TCC has no change notification, so check once a second while open.
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.window?.isVisible == true else { return }
                if AccessibilityPermission.isGranted, !self.state.isGranted {
                    self.state.isGranted = true
                    try? await Task.sleep(for: .seconds(1.4))
                    self.close()
                    return
                }
            }
        }
    }

    private func close() {
        pollTask?.cancel()
        window?.close()
    }
}

@MainActor
@Observable
final class OnboardingState {
    var isGranted = false
}

private struct OnboardingView: View {
    let state: OnboardingState
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.resolve(scheme, reduceTransparency: false)
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.accent)
                .frame(width: 56, height: 56)
                .overlay {
                    ClipboardGlyph(color: .white, size: 32)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(state.isGranted ? "You're all set" : "Let Clipboard paste for you")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.text)
                Text(state.isGranted
                     ? "⌘↵ now pastes straight into the app you were using."
                     : "⌘↵ pastes the selected item straight into the app you were using. To do that, Clipboard presses ⌘V on your behalf, which macOS only allows for apps you've approved under Accessibility.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !state.isGranted {
                VStack(alignment: .leading, spacing: 6) {
                    step(1, "Click **Open System Settings**.")
                    step(2, "Turn on **Clipboard** under Privacy & Security › Accessibility.")
                    step(3, "Come back. This window closes by itself.")
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.chip, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("Clipboard never reads your screen or your keystrokes. Until you allow it, ⌘↵ copies instead.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Spacer()
                    Button("Not Now", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                    Button("Open System Settings", action: onOpenSettings)
                        .keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
            } else {
                Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.success)
            }
        }
        .padding(28)
        .frame(width: 420)
        .animation(.easeOut(duration: 0.2), value: state.isGranted)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

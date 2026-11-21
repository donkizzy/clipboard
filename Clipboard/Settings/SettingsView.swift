import AppKit
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

enum SettingsTab: Hashable {
    case general, privacy, about
}

/// Actions the Settings window can trigger outside itself.
@MainActor
struct SettingsActions {
    var showAccessibilityOnboarding: () -> Void
    var clearHistory: () -> Void
}

struct SettingsView: View {
    @Bindable var preferences: Preferences
    let launchAtLogin: LaunchAtLogin
    let actions: SettingsActions
    @Binding var tab: SettingsTab

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings(preferences: preferences, launchAtLogin: launchAtLogin, actions: actions)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            PrivacySettings(preferences: preferences, actions: actions)
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
                .tag(SettingsTab.privacy)
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 520)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Bindable var preferences: Preferences
    let launchAtLogin: LaunchAtLogin
    let actions: SettingsActions

    @State private var accessibilityGranted = AccessibilityPermission.isGranted

    var body: some View {
        Form {
            Section {
                LabeledContent("Open Clipboard") {
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                }
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled || launchAtLogin.requiresApproval },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if launchAtLogin.requiresApproval {
                    approvalNote
                }
                if let error = launchAtLogin.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                Picker("Appearance", selection: $preferences.appearance) {
                    Text("System").tag(AppearancePreference.system)
                    Text("Dark").tag(AppearancePreference.dark)
                    Text("Light").tag(AppearancePreference.light)
                }
                .pickerStyle(.segmented)
                Toggle("Keep pinned items at the top", isOn: $preferences.pinnedOnTop)
            }

            Section {
                Picker("Keep history", selection: $preferences.historyLimit) {
                    ForEach(Preferences.historyLimitOptions, id: \.self) { limit in
                        Text(limit.map { "\($0.formatted()) items" } ?? "Unlimited").tag(limit)
                    }
                }
                Text("Pinned items are always kept and don't count towards the limit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Paste") {
                LabeledContent("Paste into apps with ⌘↵") {
                    if accessibilityGranted {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Set Up…", action: actions.showAccessibilityOnboarding)
                    }
                }
                Text("Pasting needs Accessibility access so Clipboard can press ⌘V for you. Without it, ⌘↵ copies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { launchAtLogin.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
            accessibilityGranted = AccessibilityPermission.isGranted
        }
    }

    private var approvalNote: some View {
        HStack {
            Text("Allow Clipboard in System Settings › General › Login Items.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Open…") { launchAtLogin.openSystemSettings() }
                .controlSize(.small)
        }
    }
}

// MARK: - Privacy

private struct PrivacySettings: View {
    @Bindable var preferences: Preferences
    let actions: SettingsActions

    @State private var isConcealedLocked = true
    @State private var isConfirmingUnlock = false
    @State private var selection: String?

    var body: some View {
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Toggle("Ignore passwords and other concealed items", isOn: $preferences.ignoresConcealed)
                        .disabled(isConcealedLocked)
                    Spacer()
                    Button {
                        if isConcealedLocked { isConfirmingUnlock = true } else { isConcealedLocked = true }
                    } label: {
                        Image(systemName: isConcealedLocked ? "lock.fill" : "lock.open.fill")
                    }
                    .buttonStyle(.borderless)
                    .help(isConcealedLocked ? "Unlock to change" : "Lock")
                    .accessibilityLabel(isConcealedLocked ? "Unlock setting" : "Lock setting")
                }
                Text("Password managers mark what they copy as concealed. Clipboard never reads or stores those items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Fetch link titles and icons", isOn: $preferences.fetchesLinkPreviews)
                Text("Loads each copied web link once to show its title and icon. Local and private-network addresses are never fetched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Ignored apps") {
                IgnoredAppsList(bundleIDs: $preferences.ignoredBundleIDs, selection: $selection)
                Text("Nothing copied in these apps is recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("History") {
                    Button("Clear History…", action: actions.clearHistory)
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .alert("Record concealed items?", isPresented: $isConfirmingUnlock) {
            Button("Unlock", role: .destructive) { isConcealedLocked = false }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Turning this off lets Clipboard store passwords and other sensitive items in its history.")
        }
    }
}

private struct IgnoredAppsList: View {
    @Binding var bundleIDs: Set<String>
    @Binding var selection: String?

    private var sortedApps: [IgnoredApp] {
        bundleIDs.map(IgnoredApp.init).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(sortedApps) { app in
                HStack(spacing: 8) {
                    AppIconView(bundleID: app.id, size: 18)
                    Text(app.name)
                    Spacer()
                    if !app.isInstalled {
                        Text("Not installed").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .tag(app.id)
            }
        }
        .frame(height: 150)
        .onDeleteCommand { removeSelected() }

        HStack(spacing: 0) {
            Menu {
                let candidates = runningApps
                if candidates.isEmpty {
                    Text("No other apps running")
                }
                ForEach(candidates, id: \.bundleID) { app in
                    Button(app.name) { bundleIDs.insert(app.bundleID) }
                }
                Divider()
                Button("Choose App…") { chooseApp() }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Add app")

            Button {
                removeSelected()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(selection == nil)
            .padding(.leading, 8)
            .accessibilityLabel("Remove app")

            Spacer()

            Button("Restore Defaults") {
                bundleIDs = CapturePolicy.defaultIgnoredBundleIDs
            }
            .controlSize(.small)
        }
    }

    private var runningApps: [(name: String, bundleID: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .compactMap { app in
                guard let id = app.bundleIdentifier, let name = app.localizedName, !bundleIDs.contains(id) else { return nil }
                return (name, id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func removeSelected() {
        guard let selection else { return }
        bundleIDs.remove(selection)
        self.selection = nil
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier { bundleIDs.insert(id) }
        }
    }
}

private struct IgnoredApp: Identifiable {
    let id: String
    let name: String
    let isInstalled: Bool

    init(bundleID: String) {
        id = bundleID
        let app = SourceApp(bundleID: bundleID)
        name = app?.name ?? CapturePolicy.knownAppNames[bundleID] ?? bundleID
        isInstalled = app != nil
    }
}

/// An app's icon by bundle ID, with a generic fallback.
struct AppIconView: View {
    let bundleID: String
    let size: CGFloat
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon = icon ?? AppIconCache.shared.cachedIcon(for: bundleID) {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .task(id: bundleID) { icon = await AppIconCache.shared.icon(for: bundleID) }
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Clipboard")
                .font(.system(size: 22, weight: .bold))
            Text(version)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("A keyboard-first clipboard history for macOS.")
                .font(.callout)
                .padding(.top, 4)
            Divider().padding(.vertical, 8).frame(width: 240)
            Text("Global hotkey by [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (MIT).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Released under the MIT License.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

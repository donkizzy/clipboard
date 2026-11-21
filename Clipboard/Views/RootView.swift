import SwiftUI

/// The panel itself: search, filters, results, footer, plus the Quick Look
/// and toast overlays, on a vibrant rounded surface.
struct RootView: View {
    @Bindable var model: PanelModel
    let searchFocus: SearchFocus

    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var reduceTransparency: Bool {
        #if DEBUG
        systemReduceTransparency || DebugScenario.forcesReduceTransparency
        #else
        systemReduceTransparency
        #endif
    }

    var body: some View {
        let scheme = resolvedScheme
        let palette = Palette.resolve(scheme, reduceTransparency: reduceTransparency)
        let shape = RoundedRectangle(cornerRadius: Metrics.Panel.radius, style: .continuous)
        let actions = ClipActions(model: model, focus: searchFocus)

        VStack(spacing: 0) {
            SearchBar(query: $model.query, focus: searchFocus, shortcutLabel: model.hotkeyLabel)
            FilterBar(
                selection: model.filter,
                counts: model.counts,
                layout: model.layout,
                onSelect: { model.setFilter($0) },
                onToggleLayout: { model.toggleLayout() },
                onToggleAppearance: { model.toggleAppearance(currentlyDark: scheme == .dark) }
            )
            results(actions: actions)
            FooterHints(itemCount: model.visible.count)
        }
        .blur(radius: model.isPreviewOpen ? Metrics.Preview.scrimBlur : 0, opaque: false)
        .animation(.easeOut(duration: 0.2), value: model.isPreviewOpen)
        .overlay {
            if model.isPreviewOpen, let clip = model.selected {
                QuickLookOverlay(
                    clip: clip,
                    now: model.now,
                    loadPayload: { [store = model.store] in await store.payload(for: $0) },
                    onCopy: { model.copySelected() },
                    onTogglePin: { model.togglePin(clip.id) },
                    onClose: { model.closePreview() }
                )
                .transition(.opacity.animation(.easeOut(duration: 0.2)))
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .id(toast.id)
                    .padding(.bottom, Metrics.Toast.bottomInset)
                    .transition(.asymmetric(
                        insertion: .offset(y: reduceMotion ? 0 : 10).combined(with: .opacity).animation(Motion.toast),
                        removal: .opacity.animation(.easeOut(duration: 0.12))
                    ))
            }
        }
        .background {
            ZStack {
                if palette.isTranslucent {
                    VisualEffectBackground(cornerRadius: Metrics.Panel.radius, isDark: scheme == .dark)
                }
                shape.fill(palette.panel)
            }
        }
        .clipShape(shape)
        .overlay { shape.stroke(palette.panelBorder, lineWidth: Metrics.Panel.borderWidth) }
        .outerShadow(shape, ShadowLayer.panel)
        .frame(maxWidth: Metrics.Panel.maxWidth)
        .environment(\.palette, palette)
        .environment(\.colorScheme, scheme)
    }

    @ViewBuilder
    private func results(actions: ClipActions) -> some View {
        if model.visible.isEmpty {
            EmptyState(kind: model.query.trimmingCharacters(in: .whitespaces).isEmpty
                ? (model.filter == .all ? .noHistory : .emptyFilter(model.filter))
                : .noMatches)
                .transition(.opacity.animation(.easeOut(duration: 0.3)))
        } else {
            switch model.layout {
            case .row:
                CardRow(clips: model.visible, selectedIndex: model.selectedIndex, now: model.now, actions: actions)
            case .list:
                ListView(clips: model.visible, selectedIndex: model.selectedIndex, now: model.now, actions: actions)
            }
        }
    }

    private var resolvedScheme: ColorScheme {
        switch model.preferences.appearance {
        case .system: systemScheme
        case .dark: .dark
        case .light: .light
        }
    }
}

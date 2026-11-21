import SwiftUI

struct FilterBar: View {
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    let selection: HistoryFilter
    let counts: [HistoryFilter: Int]
    let layout: PanelLayout
    let onSelect: (HistoryFilter) -> Void
    let onToggleLayout: () -> Void
    let onToggleAppearance: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(HistoryFilter.allCases) { filter in
                    FilterTab(
                        filter: filter,
                        count: counts[filter] ?? 0,
                        isActive: filter == selection,
                        action: { onSelect(filter) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                IconButton(help: "Toggle layout", action: onToggleLayout) {
                    Group {
                        if layout == .row {
                            Glyph.LayoutColumns().fill()
                        } else {
                            Glyph.LayoutRows().fill()
                        }
                    }
                    .frame(width: 16, height: 16)
                }
                .accessibilityLabel(layout == .row ? "Switch to list layout" : "Switch to card layout")
                .accessibilityIdentifier("layoutToggle")

                IconButton(help: "Toggle appearance", action: onToggleAppearance) {
                    if colorScheme == .dark {
                        Glyph.Moon().fill().frame(width: 15, height: 15)
                    } else {
                        GlyphStroke(Glyph.Sun(), width: 2, size: 17)
                    }
                }
                .accessibilityLabel(colorScheme == .dark ? "Switch to light appearance" : "Switch to dark appearance")
                .accessibilityIdentifier("appearanceToggle")
            }
            .padding(.leading, 6)
        }
        .padding(Metrics.FilterBar.padding)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

private struct FilterTab: View {
    @Environment(\.palette) private var palette
    @State private var isHovered = false

    let filter: HistoryFilter
    let count: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(filter.title)
                    .textStyle(Typography.filterTab)
                if isActive && count > 0 {
                    Text("\(count)")
                        .textStyle(Typography.filterCount)
                        .opacity(0.6)
                }
            }
            .foregroundStyle(isActive ? Color.white : palette.chipText)
            .padding(Metrics.FilterBar.tabPadding)
            .background(background, in: RoundedRectangle(cornerRadius: Metrics.FilterBar.tabRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.FilterBar.tabRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .trackHover($isHovered)
        .animation(Motion.tab, value: isActive)
        .animation(Motion.tab, value: isHovered)
        .accessibilityLabel(filter.title)
        .accessibilityValue(isActive ? "\(count) items" : "")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("filter.\(filter.title)")
    }

    private var background: Color {
        if isActive { return palette.accent }
        return isHovered ? palette.chip : .clear
    }
}

/// 30×30 chip-backed icon button in the filter bar.
private struct IconButton<Label: View>: View {
    @Environment(\.palette) private var palette
    @State private var isHovered = false

    let help: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .foregroundStyle(isHovered ? palette.text : palette.textDim)
                .frame(width: Metrics.FilterBar.buttonSize, height: Metrics.FilterBar.buttonSize)
                .background(palette.chip, in: RoundedRectangle(cornerRadius: Metrics.FilterBar.buttonRadius, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .trackHover($isHovered)
        .animation(.easeOut(duration: 0.16), value: isHovered)
    }
}

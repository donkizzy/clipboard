import SwiftUI

/// Full-panel preview of the selected item, opened with Space or a double-click.
struct QuickLookOverlay: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var fullText: String?
    let clip: ClipSnapshot
    let now: Date
    /// Loads the full payload; snapshots only carry a 2,000-character preview.
    let loadPayload: (ClipSnapshot.ID) async -> ClipPayload?
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(palette.previewScrim)
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            PreviewCard(clip: clip, fullText: fullText, now: now, onCopy: onCopy, onTogglePin: onTogglePin, onClose: onClose)
                // A fresh identity per item, so no state (icons, scroll) leaks between items.
                .id(clip.id)
                .padding(26)
                .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.94)
                .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(Motion.previewOpen) { hasAppeared = true }
        }
        .task(id: clip.id) {
            fullText = nil
            guard case .text(let text) = clip.content, text.preview.count >= ClipContent.Text.previewLimit,
                  case .text(let full)? = await loadPayload(clip.id)
            else { return }
            fullText = full
        }
        .accessibilityIdentifier("quickLook")
    }
}

private struct PreviewCard: View {
    @Environment(\.palette) private var palette
    let clip: ClipSnapshot
    let fullText: String?
    let now: Date
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onClose: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.Preview.radius, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            PreviewMedia(clip: clip, fullText: fullText)
            VStack(spacing: 14) {
                meta
                buttons
            }
            .padding(EdgeInsets(top: 14, leading: 20, bottom: 16, trailing: 20))
        }
        .frame(maxWidth: Metrics.Preview.maxWidth)
        .background(palette.previewBg)
        .clipShape(shape)
        .overlay { shape.stroke(palette.panelBorder, lineWidth: 0.5) }
        .outerShadow(shape, .preview)
        .contentShape(shape)
        .onTapGesture {} // swallow taps so they don't reach the scrim
        .accessibilityElement(children: .contain)
    }

    private var meta: some View {
        HStack(spacing: 10) {
            AppBadge(clip: clip, size: 22, radius: 6, fontSize: 11)
            Text("\(clip.sourceName) · \(RelativeTime.short(clip.createdAt, now: now))")
                .textStyle(Typography.previewMeta)
                .foregroundStyle(palette.textDim)
                .lineLimit(1)
            Spacer(minLength: 0)
            TypeBadge(
                label: clip.typeBadge,
                style: Typography.previewBadge,
                padding: EdgeInsets(top: 4, leading: 9, bottom: 4, trailing: 9),
                radius: 7
            )
        }
        .padding(.top, 2)
    }

    private var buttons: some View {
        HStack(spacing: 9) {
            PreviewButton(kind: .primary, action: onCopy) {
                Text("Copy").textStyle(Typography.previewPrimaryButton)
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("preview.copy")

            PreviewButton(kind: .secondary, action: onTogglePin) {
                Text(clip.isPinned ? "Unpin" : "Pin").textStyle(Typography.previewButton)
                    .padding(.horizontal, 5)
            }
            .fixedSize()
            .accessibilityIdentifier("preview.pin")

            PreviewButton(kind: .dismiss, action: onClose) {
                Text("Esc").textStyle(Typography.previewButton)
            }
            .frame(width: 44)
            .accessibilityLabel("Close preview")
            .accessibilityIdentifier("preview.close")
        }
    }
}

/// Quick Look action button: primary (accent), secondary (chip) or dismiss.
private struct PreviewButton<Label: View>: View {
    enum Kind { case primary, secondary, dismiss }

    @Environment(\.palette) private var palette
    @State private var isHovered = false

    let kind: Kind
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Button(action: action) {
            label()
                .foregroundStyle(foreground)
                .padding(.vertical, 11)
                .padding(.horizontal, kind == .secondary ? 11 : 0)
                .frame(maxWidth: .infinity)
                .background(background, in: shape)
                .brightness(kind == .primary && isHovered ? 0.03 : 0) // ≈ CSS brightness(1.08)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .trackHover($isHovered)
        .animation(.easeOut(duration: 0.14), value: isHovered)
    }

    private var foreground: Color {
        switch kind {
        case .primary: .white
        case .secondary: palette.text
        case .dismiss: palette.textDim
        }
    }

    private var background: Color {
        switch kind {
        case .primary: palette.accent
        case .secondary, .dismiss: isHovered ? palette.cardHover : palette.chip
        }
    }
}

/// Top section of the preview card, by item kind.
private struct PreviewMedia: View {
    @Environment(\.palette) private var palette
    let clip: ClipSnapshot
    let fullText: String?

    var body: some View {
        switch clip.content {
        case .image(let image):
            ImageArtwork(image: image, preferFullSize: true)
                .frame(height: Metrics.Preview.imageHeight)
                .frame(maxWidth: .infinity)

        case .text(let text):
            PreviewText(text: text, fullText: fullText)

        case .link(let link):
            HStack(spacing: 12) {
                FaviconTile(link: link, size: 46, radius: 11, style: Typography.faviconInitialPreview)
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title ?? clip.title)
                        .textStyle(Typography.previewLinkTitle)
                        .foregroundStyle(palette.text)
                    Text(link.url.displayString)
                        .textStyle(Typography.previewLinkURL)
                        .foregroundStyle(palette.accent)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: 24, leading: 22, bottom: 8, trailing: 22))

        case .file(let file):
            let accent = file.accent?.color ?? palette.accent
            VStack(spacing: 12) {
                Group {
                    if file.isDirectory {
                        Glyph.FolderBack().fill(accent)
                    } else {
                        Glyph.DocumentSmall().fill(accent).opacity(0.9)
                    }
                }
                .frame(width: 72, height: 72)
                Text(clip.title)
                    .textStyle(Typography.previewFileTitle)
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(EdgeInsets(top: 32, leading: 22, bottom: 12, trailing: 22))
        }
    }
}

/// Text preview that hugs its content up to 300pt, then scrolls.
private struct PreviewText: View {
    @Environment(\.palette) private var palette
    @State private var contentHeight: CGFloat?
    let text: ClipContent.Text
    let fullText: String?

    /// Enough for any realistic preview while keeping layout fast.
    private static let displayLimit = 100_000

    private var displayed: (text: String, isTruncated: Bool) {
        let source = fullText ?? text.preview
        guard source.count > Self.displayLimit else { return (source, false) }
        return (String(source.prefix(Self.displayLimit)), true)
    }

    var body: some View {
        let displayed = displayed
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(displayed.text)
                    .textStyle(text.isCode ? Typography.previewCode : Typography.previewText)
                    .foregroundStyle(palette.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if displayed.isTruncated {
                    Text("Showing the first \(Self.displayLimit.formatted()) characters. Copy to get everything.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.textFaint)
                }
            }
            .padding(EdgeInsets(top: 22, leading: 22, bottom: 6, trailing: 22))
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(contentHeight ?? Metrics.Preview.textMaxHeight, Metrics.Preview.textMaxHeight))
    }
}

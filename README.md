# Clipboard

A native macOS clipboard history manager: a floating, translucent panel opened with **⌘⇧V** that
shows recent clipboard items as cards or rows, with search, type filters, pinning, Quick Look and
keyboard-first navigation.

Swift 6 · SwiftUI + AppKit · macOS 14 Sonoma or later · no web views.

> **Status:** in development, milestone 1 of 6 (panel and visual design on demo data).
> Clipboard capture, persistence, paste-back and Settings are still to come.

## Build and run

Requirements: Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate            # project.yml → Clipboard.xcodeproj
open Clipboard.xcodeproj     # or build from the command line:
xcodebuild -scheme Clipboard -derivedDataPath build/DerivedData build
./scripts/test.sh            # unit tests
```

The app lives in the menu bar (there's no Dock icon). For now the panel opens at launch and can be
reopened from the menu bar extra.

### Signing

A fresh clone builds with ad-hoc signing ("Sign to Run Locally"). Paste-back needs the Accessibility
permission, and macOS revokes it whenever an ad-hoc signed binary changes. To keep it across
rebuilds, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` (git-ignored) and set your
`DEVELOPMENT_TEAM`.

### Demo mode and debug scenarios

`--demo` fills the panel with the twelve sample items from the design. Debug builds also accept
scenarios for screenshots and manual QA, and the stored preferences can be overridden with launch
arguments:

```sh
Clipboard.app/Contents/MacOS/Clipboard --demo -layout list -appearance light --scenario preview --select 4
```

`--scenario` takes `preview`, `toast` or `empty`. `--select N` and `--query TEXT` are also available.

## Architecture

| Folder | Responsibility |
|---|---|
| `App/` | Entry point, menu bar extra, composition root (`AppEnvironment`) |
| `Panel/` | `FloatingPanel` (non-activating `NSPanel`), `PanelController` (show/hide/position), vibrancy |
| `State/` | `PanelModel`: query, filter, selection, Quick Look and toasts (UI-framework agnostic) |
| `Model/` | `ClipSnapshot` (immutable, `Sendable`), `HistoryQuery` (pure search/filter), `ClipStore` |
| `Views/` | SwiftUI views for every part of the panel |
| `Theme/` | Design tokens (colours, metrics, typography, motion), SVG-ported glyphs, CSS-accurate shadows |
| `Support/` | Relative time, demo seed, debug scenarios |

Views only ever see `ClipSnapshot` values. Search runs in memory over a pre-folded `searchKey`, and
the panel window is created once and reused, so opening it costs a reposition and a fade.

## Deviations from the design spec

Where SwiftUI or AppKit can't reproduce a CSS detail exactly:

- **Backdrop blur.** `blur(40px) saturate(180%)` is approximated with an `NSVisualEffectView`
  (`.popover` material, behind-window blending) under the spec's panel tint. AppKit doesn't let you
  set the blur radius or saturation.
- **Borderless window.** The panel is a borderless `NSPanel` rather than a titled window with a
  transparent titlebar, so the system frame doesn't draw its own corners, border or shadow over the
  design's.
- **Shadows.** CSS `box-shadow` values are reproduced with an outer-only shadow view (spread is
  emulated by insetting the shadow source). A SwiftUI shadow radius is treated as CSS blur ÷ 2.
- **Font weight 590.** This is built as an interpolated `NSFont` weight. SF Pro may snap it to the
  nearest weight its instances include.
- **Small blurs.** The blurred chips and the toast use SwiftUI materials under the token colour, so
  the blur radius is approximate. The Quick Look 18px backdrop blur is applied to the panel content
  itself (σ = 9pt).
- **Footer key chips.** Symbol-only keys (↵, ⌫, ←→) use SF Pro instead of SF Mono, because SF Mono
  has no ⌫ glyph and joins ←→ into a single ↔.
- **Dates.** Items older than a week show "12 Nov", with the year added for previous years.

## License

MIT. See [LICENSE](LICENSE).

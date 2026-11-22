# Contributing to Clipboard

## Build from a clean checkout

Use a Mac with full Xcode 26 or later, Swift tools 6.2 or later and XcodeGen. The app itself targets macOS 14. Open Xcode once to complete its setup. Check that `xcodebuild -version` reports the intended Xcode.

```sh
git clone https://github.com/donkizzy/clipboard.git
cd clipboard
brew install xcodegen
xcodegen generate
xcodebuild -project Clipboard.xcodeproj -scheme Clipboard -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Release/Clipboard.app
```

The build fetches KeyboardShortcuts through Swift Package Manager. For an installed copy, quit Clipboard, then drag the built app to Applications in Finder. Run only one copy at a time so the global shortcut reaches the app you expect.

For development, open the generated `Clipboard.xcodeproj`. The **Clipboard** scheme enables `--demo` in Xcode. To test real capture, open **Product → Scheme → Edit Scheme → Run → Arguments** and uncheck it. Launching the Release app directly as above uses real capture. Edit `project.yml` for persistent project changes and regenerate after editing it.

### Signing

A fresh clone builds with ad-hoc signing ("Sign to Run Locally"). Paste-back needs the Accessibility
permission, and macOS revokes it whenever an ad-hoc signed binary changes. To keep it across
rebuilds, give the build a stable identity in `Config/Local.xcconfig` (git-ignored). Either:

- run `./scripts/make-signing-cert.sh`, which creates a self-signed code-signing certificate in your
  login keychain and writes the config for you (no Apple Developer account needed), or
- copy `Config/Local.xcconfig.example` and set your `DEVELOPMENT_TEAM`.

Debug builds carry a `disable-library-validation` entitlement so the Hardened Runtime test host can
load the test bundle when signed without a Team ID. Release builds don't.

## Tests

```sh
./scripts/test.sh       # unit tests (Swift Testing + XCTest performance baselines)
./scripts/ui-test.sh    # UI tests (XCUITest, demo mode)
```

- **Unit tests** cover:
  - the classifier and code detection (including the edge cases);
  - privacy filtering;
  - capture end to end, against a private, uniquely named pasteboard, never yours;
  - dedupe, retention with pinned items, and image and favicon cleanup;
  - the write queue and optimistic updates;
  - search and filter combinations;
  - the full keyboard map, including non-Latin layouts and AZERTY;
  - scroll-into-view maths, relative time, paste-board writes, VoiceOver labels and preferences.
- **UI tests** open the panel in demo mode and drive arrow keys, Space and Esc, typing into search,
  ⌘1–⌘6 and filter clicks, and the layout toggle.

### Demo mode, benchmarks and debug scenarios

- **`--demo`** fills an in-memory store with the twelve sample items from the design. It never
  records or modifies your real history.
- **`--demo-count N`** pads the demo store to *N* items.
- **`--benchmark-open`** opens and closes the panel 30 times and prints the timings.
- **Preference overrides:** launch arguments such as `-layout list` and `-appearance light`
  override the stored preferences.
- **Debug-only scenarios** support screenshots and manual QA:
  - `--scenario preview|toast|empty|settings-general|settings-privacy|settings-about`
  - `--select N` and `--query TEXT`
  - `--backdrop` puts the design's wallpaper behind the panel. Every README screenshot uses it, so
    none show a real desktop.
  - `--reduce-transparency` renders the solid palette without changing system settings.

```sh
APP=build/DerivedData/Build/Products/Release/Clipboard.app/Contents/MacOS/Clipboard
$APP --demo --demo-count 1000 --benchmark-open
# open-benchmark items=1000 first=18.6ms median=11.6ms p95=13.7ms max=13.9ms
```

## Architecture

```
Clipboard/
  App/        entry point, menu bar extra, composition root, global hotkey
  Panel/      FloatingPanel (non-activating NSPanel), PanelController, toast window, vibrancy
  Monitor/    PasteboardMonitor (actor), reader, privacy filter, classifier, code detector, processor
  Model/      ClipSnapshot, HistoryQuery, ClipItem (@Model), HistoryDatabase (model actor), HistoryStore
  Paste/      PasteService (typed writes, ⌘V via CGEvent), Accessibility permission and onboarding
  State/      PanelModel, KeyRouter, scroll-into-view maths
  Views/      SwiftUI views for every part of the panel
  Theme/      design tokens, typography, motion, SVG-ported glyphs, CSS-accurate shadows
  Settings/   Preferences, SettingsView, its window controller, launch at login
  Support/    caches (images, app icons), link metadata, thumbnails, paths, logging, demo, debug
```

- **Values only in views.** Views only ever see `ClipSnapshot`, an immutable `Sendable` value. Text
  is capped to a preview, and full payloads are loaded on demand. Search runs in memory over a
  pre-folded `searchKey`.
- **SwiftData stays in one actor.** It runs only inside `HistoryDatabase`, a model actor created off
  the main thread; on macOS 14, a `ModelContext` created on the main thread stays bound to it.
  - `HistoryStore` keeps the in-memory array the panel reads and sends every write through a FIFO
    queue.
  - Pin and delete are applied to that array immediately, and the database's view replaces it once
    the queue drains.
  - A store that can't be opened is moved aside rather than crashing the app.
- **The model is UI-agnostic.** `PanelModel` tracks the selection by item identity, so a reorder or a
  new capture never moves it to a different item. `PanelController` owns the AppKit side: window,
  focus, key monitor, copy and paste.
- **Nothing heavy on the main thread.** Pasteboard reads, classification, hashing, image encoding,
  thumbnailing, icon rendering and decoding all run on background actors or detached tasks.

## Performance

The panel window is created once and pre-rendered invisibly at launch, so opening it is a reposition
and a fade. Measured with `--benchmark-open` (Release build, 1,000 items, Apple silicon):

| | First open | Median | p95 |
|---|---|---|---|
| Cards | 19–30 ms | 11.6 ms | 14 ms |
| List | 14–18 ms | 11 ms | 13 ms |

The budget is 100 ms. Lazy stacks keep the cost flat: 5,000 items open in about 21 ms.

## Sending a change

Describe the user-visible effect, include the test command and result, and use demo data for screenshots. For changes to capture or storage, cover ignored items and existing history. See [release verification](docs/RELEASING.md) for packaging and the first-launch checks.

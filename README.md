# Clipboard

A native macOS menu bar app for finding something you copied earlier. Press **Command + Shift + V** (⌘⇧V) to search text, code, links, images and files. Pin items you reuse, preview them with Space, or paste them back into the app you were using.

## Install

**[Download Clipboard for macOS (0.1.0 RC 1, ZIP)](https://github.com/donkizzy/clipboard/releases/download/v0.1.0-rc.1/Clipboard-0.1.0-macOS-local-rc.zip)**

Requires macOS 14 Sonoma or later. The ZIP includes Apple silicon and Intel support. This prerelease is ad-hoc signed and unnotarized, so Gatekeeper may block it on first launch.

Double-click the ZIP in Finder, drag **Clipboard.app** into **Applications**, then open it. The [release notes and SHA-256 checksum](https://github.com/donkizzy/clipboard/releases/tag/v0.1.0-rc.1) include verification instructions and tested configurations. You can also [build Clipboard from source](CONTRIBUTING.md#build-from-a-clean-checkout).

### Your first clip

1. Look for the clipboard icon in the menu bar. Open it and choose **Settings… → Privacy** if you want to adjust capture before you start.
2. In TextEdit, type a short phrase and copy it. Press **Command + Shift + V** (⌘⇧V) to open Clipboard. If another app uses that shortcut, choose **Open Clipboard** from the menu bar and change the shortcut in **Settings… → General**.
3. Select the phrase and press **Return**. Switch to your document and press **Command + V** (⌘V) to paste it.
4. For direct paste, press **Command + Return** (⌘↵) in Clipboard. On first use, Clipboard copies the item and offers to open **System Settings → Privacy & Security → Accessibility**. Grant access to Clipboard if you want it to send the paste keystroke. Browsing history and copying with Return work without this permission.

![Clipboard in dark mode](docs/images/panel-dark.png)

| Quick Look | Light, list layout |
|---|---|
| ![Quick Look preview of a code snippet](docs/images/quick-look-dark.png) | ![The list layout in light mode](docs/images/panel-light-list.png) |

## Capture and privacy

History lives in your macOS account under `~/Library/Application Support/Clipboard/`. It includes the history database, saved images, thumbnails and favicons. File entries refer to the original files, so pasting a file requires it to still exist.

- **Link previews use the network by default.** Copying an eligible web URL can contact the site to fetch its title and icon, including when the URL contains private query parameters. Turn off **Settings… → Privacy → Fetch link titles and icons** to disable these requests.
- **Sensitive items.** By default Clipboard skips items marked concealed and copies attributed to ignored apps, including 1Password, Bitwarden, Keychain Access and Passwords. An unmarked password copied from another app can enter history. Add apps to the ignore list in Privacy settings, or choose **Pause Capture** from the menu bar. Capture resumes on relaunch.
- **Retention.** Clipboard keeps the newest 500 unpinned items by default. Adjust the limit in General settings. Copying the same item again moves it to the top. Pinned items stay until you delete or unpin them. **Clear History… keeps pinned items.**
- **Personal data in reports.** Use a made-up clip when sharing a screenshot or reporting a bug. For sensitive reports, see [Security](SECURITY.md).

## Keyboard

| Key | Action |
|---|---|
| Command + Shift + V (⌘⇧V) | Toggle the panel (global, configurable) |
| Up Arrow (↑) or Down Arrow (↓) | Move the selection |
| Left Arrow (←) or Right Arrow (→) | Move the selection in the card layout, when the search is empty or unfocused |
| Return (↵) | Copy, then close |
| Command + Return (⌘↵) | Paste into the previous app |
| Space | Toggle Quick Look (when the search isn't focused) |
| Delete (⌫) or Forward Delete (⌦) | Delete the selected item (when the search isn't focused) |
| Command + P (⌘P) | Pin or unpin |
| Command + 1 through Command + 6 (⌘1–⌘6) | All, Text, Links, Images, Files, Pinned |
| Tab | Switch focus between search and results |
| Command + Comma (⌘,) | Settings |
| Escape (Esc) | Close the preview, then clear the search, then close the panel |

The search field has focus when the panel opens. Moving the selection hands focus to the results,
so Space and Delete act on the selection. Typing any character puts focus back in the search field and
adds the character there.

## Update or uninstall

To update manually, quit Clipboard from its menu, replace the copy in Applications, and reopen it. History and preferences live outside the app bundle. After replacing a locally signed build, macOS may ask for Accessibility access again.

To uninstall, turn off **Launch at login** if enabled, quit Clipboard, and move the app to Trash. To also remove all saved history, including pins and images, use **Finder → Go → Go to Folder…**, enter `~/Library/Application Support/Clipboard/`, and move that folder to Trash. To reset the app’s preferences, run `defaults delete com.amosgodwin.Clipboard` while Clipboard is closed. You can remove its Accessibility entry in System Settings.

## Project

Clipboard uses SwiftUI, AppKit and SwiftData. It supports VoiceOver, Reduce Motion and Reduce Transparency. For build instructions, tests, demo mode and architecture, see [Contributing](CONTRIBUTING.md). Maintainers can use the [release guide](docs/RELEASING.md) to build and verify the downloadable archive.

Released under the [MIT License](LICENSE). The global shortcut uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts).

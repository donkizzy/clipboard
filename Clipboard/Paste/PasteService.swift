import AppKit
import Carbon.HIToolbox
import UniformTypeIdentifiers

/// Writes history items back to the pasteboard, in the representation the
/// receiving app expects, and sends the ⌘V keystroke for paste-back.
@MainActor
final class PasteService {
    private let ownWrites: OwnPasteboardWrites?
    private let pasteboard: NSPasteboard
    /// Kept alive while it might still be asked for lazy TIFF data.
    private var tiffProvider: LazyTIFFProvider?

    init(ownWrites: OwnPasteboardWrites?, pasteboard: NSPasteboard = .general) {
        self.ownWrites = ownWrites
        self.pasteboard = pasteboard
    }

    /// Writes `payload` to the pasteboard and marks the change as our own, so
    /// capture doesn't record it again. Returns `false` if nothing was written.
    @discardableResult
    func write(_ payload: ClipPayload) async -> Bool {
        // Image bytes can be large; read them off the main thread first.
        var imageData: (Data, NSPasteboard.PasteboardType)?
        if case .image(let url) = payload {
            imageData = await Task.detached(priority: .userInitiated) { Self.readImage(at: url) }.value
            guard imageData != nil else { return false }
        }

        let changeCount = pasteboard.clearContents()
        ownWrites?.register(changeCount)

        switch payload {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .link(let url):
            // Both forms: browsers and Finder read public.url, text fields read the string.
            pasteboard.setString(url.absoluteString, forType: .URL)
            pasteboard.setString(url.absoluteString, forType: .string)
        case .image:
            guard let (data, type) = imageData else { return false }
            let item = NSPasteboardItem()
            item.setData(data, forType: type)
            // Many older apps only read TIFF; produce it only if someone asks.
            let provider = LazyTIFFProvider(source: data)
            item.setDataProvider(provider, forTypes: [.tiff])
            tiffProvider = provider
            pasteboard.writeObjects([item])
        case .files(let urls):
            pasteboard.writeObjects(urls.map { $0 as NSURL })
        }

        if let bundleID = Bundle.main.bundleIdentifier {
            pasteboard.setString(bundleID, forType: PasteboardReader.sourceType)
        }
        ownWrites?.register(pasteboard.changeCount)
        return true
    }

    /// Posts ⌘V to whichever app has keyboard focus. Requires the
    /// Accessibility permission; without it macOS silently drops the events.
    @discardableResult
    func sendPasteKeystroke() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        // Keep keys the user is still holding (the ⌘ of ⌘↵) from leaking in.
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let keyCode = KeyboardLayout.keyCode(producing: "v") ?? CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        return true
    }

    private nonisolated static func readImage(at url: URL) -> (Data, NSPasteboard.PasteboardType)? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let isJPEG = UTType(filenameExtension: url.pathExtension)?.conforms(to: .jpeg) == true
        return (data, isJPEG ? NSPasteboard.PasteboardType(UTType.jpeg.identifier) : .png)
    }
}

/// Supplies a TIFF rendition of an image only when an app requests it.
private final class LazyTIFFProvider: NSObject, NSPasteboardItemDataProvider {
    private let source: Data

    init(source: Data) {
        self.source = source
    }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        guard type == .tiff, let tiff = NSImage(data: source)?.tiffRepresentation else { return }
        item.setData(tiff, forType: .tiff)
    }
}

/// Finds which physical key types a character with ⌘ held in the current
/// keyboard layout, so paste works on Dvorak, AZERTY and "Dvorak – QWERTY ⌘".
enum KeyboardLayout {
    static func keyCode(producing character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        let target = String(character).lowercased()
        let commandModifier = UInt32((cmdKey >> 8) & 0xFF)

        return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for keyCode in 0..<128 {
                var deadKeyState: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), commandModifier,
                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState, chars.count, &length, &chars
                )
                if status == noErr, length > 0, String(utf16CodeUnits: chars, count: length).lowercased() == target {
                    return CGKeyCode(keyCode)
                }
            }
            return nil
        }
    }
}

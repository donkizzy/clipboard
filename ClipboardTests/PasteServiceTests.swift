import AppKit
import Testing
import UniformTypeIdentifiers
@testable import Clipboard

/// Writes go to a private, uniquely named pasteboard, never the user's.
@MainActor
@Suite("PasteService")
struct PasteServiceTests {
    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipboardTests-\(UUID().uuidString)"))
    private let ownWrites = OwnPasteboardWrites()
    private var service: PasteService { PasteService(ownWrites: ownWrites, pasteboard: pasteboard) }

    private var types: Set<String> { Set(pasteboard.types?.map(\.rawValue) ?? []) }

    @Test("Text is written as a plain string")
    func text() async {
        #expect(await service.write(.text("hello")))
        #expect(pasteboard.string(forType: .string) == "hello")
    }

    @Test("Links are written as both a URL and a string")
    func link() async {
        let url = URL(string: "https://framer.com/motion")!
        #expect(await service.write(.link(url)))
        #expect(pasteboard.string(forType: .URL) == url.absoluteString)
        #expect(pasteboard.string(forType: .string) == url.absoluteString)
    }

    @Test("Images are written as PNG, with TIFF available on request")
    func image() async throws {
        let file = try TestSupport.temporaryPaths().imagesDirectory.appending(path: "x.png")
        let data = TestSupport.pngData(width: 12, height: 8)
        try data.write(to: file)

        #expect(await service.write(.image(file)))
        #expect(pasteboard.data(forType: .png) == data)
        #expect(types.contains(NSPasteboard.PasteboardType.tiff.rawValue))
        let tiff = try #require(pasteboard.data(forType: .tiff))
        #expect(NSImage(data: tiff)?.representations.first?.pixelsWide == 12)
    }

    @Test("A missing image file writes nothing")
    func missingImage() async {
        #expect(await service.write(.image(URL(filePath: "/nonexistent/image.png"))) == false)
    }

    @Test("Files are written as file URLs")
    func files() async throws {
        let root = try TestSupport.temporaryPaths().root
        let urls = [root.appending(path: "a.txt"), root.appending(path: "b.txt")]
        for url in urls { try Data().write(to: url) }
        #expect(await service.write(.files(urls)))
        let read = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        #expect(read?.map(\.path) == urls.map(\.path))
    }

    @Test("Files that no longer exist write nothing")
    func missingFiles() async {
        #expect(await service.write(.files([URL(filePath: "/nonexistent/gone.pdf")])) == false)
    }

    @Test("Writes are registered as our own, so capture ignores them")
    func ownWrite() async {
        await service.write(.text("ours"))
        #expect(ownWrites.consume(pasteboard.changeCount))
    }

    @Test("Writes carry the source marker")
    func sourceMarker() async {
        await service.write(.text("marked"))
        #expect(pasteboard.string(forType: PasteboardReader.sourceType) == Bundle.main.bundleIdentifier)
    }
}

@Suite("HotkeyLabel")
struct HotkeyLabelTests {
    @Test("Modifiers are listed command-first, as in the design")
    func ordering() {
        #expect(HotkeyLabel.format(modifiers: [.shift, .command], key: "V") == "⌘⇧V")
        #expect(HotkeyLabel.format(modifiers: [.control, .option, .shift, .command], key: "K") == "⌘⇧⌥⌃K")
    }

    @Test("The current layout has a key for V")
    func layoutLookup() {
        #expect(KeyboardLayout.keyCode(producing: "v") != nil)
    }
}

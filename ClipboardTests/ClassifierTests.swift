import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Clipboard

@Suite("ItemClassifier")
struct ClassifierTests {
    private func snapshot(
        types: [String] = [UTType.utf8PlainText.identifier],
        string: String? = nil,
        files: [URL] = [],
        image: PasteboardSnapshot.ImageData? = nil
    ) -> PasteboardSnapshot {
        PasteboardSnapshot(changeCount: 1, types: types, string: string, fileURLs: files, image: image)
    }

    private let png = PasteboardSnapshot.ImageData(data: TestSupport.pngData(), typeIdentifier: UTType.png.identifier)

    @Test("Plain text")
    func text() {
        #expect(ItemClassifier.classify(snapshot(string: "hello world")) == .text("hello world"))
    }

    @Test("Whitespace-only text is ignored")
    func whitespace() {
        #expect(ItemClassifier.classify(snapshot(string: " \n\t ")) == nil)
    }

    @Test("A single http(s) URL is a link", arguments: [
        "https://framer.com/motion", "http://example.org", "  https://linear.app/eng/issue/ENG-482\n",
    ])
    func link(string: String) throws {
        let result = ItemClassifier.classify(snapshot(string: string))
        guard case .link(let url) = result else {
            Issue.record("Expected a link, got \(String(describing: result))")
            return
        }
        #expect(url.absoluteString == string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test("Not links: other schemes, prose with a URL, bare hosts", arguments: [
        "ftp://example.com", "see https://example.com for details", "example.com",
        "https://localhost", "mailto:hello@studioform.co", "https:///path",
    ])
    func notLink(string: String) {
        #expect(ItemClassifier.classify(snapshot(string: string)) == .text(string))
    }

    @Test("Files win over everything")
    func files() {
        let url = URL(filePath: "/tmp/report.pdf")
        let result = ItemClassifier.classify(snapshot(string: "/tmp/report.pdf", files: [url], image: png))
        #expect(result == .files([url]))
    }

    @Test("An image listed first is an image, even with text alongside")
    func primaryImage() {
        let types = [UTType.png.identifier, UTType.html.identifier, UTType.utf8PlainText.identifier]
        #expect(ItemClassifier.classify(snapshot(types: types, string: "<img>", image: png)) == .image(png))
    }

    @Test("A rendering attached to copied text loses to the text (Numbers, Word)")
    func secondaryImage() {
        let tiff = PasteboardSnapshot.ImageData(data: png.data, typeIdentifier: UTType.tiff.identifier)
        let types = ["com.apple.iWork.TSPNativeData", UTType.rtf.identifier, UTType.utf8PlainText.identifier, UTType.tiff.identifier]
        #expect(ItemClassifier.classify(snapshot(types: types, string: "Q3 revenue", image: tiff)) == .text("Q3 revenue"))
    }

    @Test("An image with no text at all is an image")
    func imageOnly() {
        #expect(ItemClassifier.classify(snapshot(types: [UTType.png.identifier], image: png)) == .image(png))
    }
}

@Suite("CodeDetector")
struct CodeDetectorTests {
    @Test("Code from editors and terminals is always code", arguments: [
        "com.microsoft.VSCode", "com.apple.dt.Xcode", "com.apple.Terminal",
        "com.googlecode.iterm2", "com.todesktop.230313mzl4w4u92",
    ])
    func codeApps(bundleID: String) {
        #expect(CodeDetector.isCode("ls -la", sourceBundleID: bundleID))
    }

    @Test("Recognises code by syntax", arguments: [
        "const debounce = (fn, ms) => {\n  let t;\n  return t;\n};",
        "func greet() {\n    print(\"hi\")\n}",
        "def main():\n    pass\n    return 1",
        "let x = 1;",
        "{\"name\": \"clipboard\", \"version\": 2}",
        "SELECT * FROM items WHERE pinned = 1;",
        "#include <stdio.h>\nint main() { return 0; }",
    ])
    func code(text: String) {
        #expect(CodeDetector.isCode(text, sourceBundleID: "com.apple.Notes"))
    }

    @Test("Prose stays prose", arguments: [
        "Meeting notes: ship v2.3 by Friday, QA runs Thursday.",
        "hello@studioform.co",
        "415 Natoma St, Suite 200\nSan Francisco, CA 94103",
        "I came; I saw; I left.",
        "Shopping:\n  - milk\n  - eggs\n  - bread",
        "Use {braces} sparingly in prose.",
        "Let me know if this works for you",
    ])
    func prose(text: String) {
        #expect(!CodeDetector.isCode(text, sourceBundleID: "com.apple.Notes"))
    }
}

@Suite("PrivacyFilter")
struct PrivacyFilterTests {
    private let policy = CapturePolicy()

    @Test("Concealed, transient and auto-generated items are skipped")
    func markers() {
        let text = UTType.utf8PlainText.identifier
        #expect(PrivacyFilter.skipReason(types: [text, PrivacyFilter.concealedType], sourceBundleID: nil, policy: policy) == .concealed)
        #expect(PrivacyFilter.skipReason(types: [text, PrivacyFilter.transientType], sourceBundleID: nil, policy: policy) == .transient)
        #expect(PrivacyFilter.skipReason(types: [text, PrivacyFilter.autoGeneratedType], sourceBundleID: nil, policy: policy) == .autoGenerated)
        #expect(PrivacyFilter.skipReason(types: [text, "com.agilebits.onepassword"], sourceBundleID: nil, policy: policy) == .concealed)
    }

    @Test("Password managers are ignored by default", arguments: ["com.1password.1password", "com.bitwarden.desktop", "com.apple.keychainaccess"])
    func ignoredApps(bundleID: String) {
        #expect(PrivacyFilter.skipReason(types: ["public.utf8-plain-text"], sourceBundleID: bundleID, policy: policy) == .ignoredApp(bundleID))
    }

    @Test("Ordinary items are captured")
    func ordinary() {
        #expect(PrivacyFilter.skipReason(types: ["public.utf8-plain-text"], sourceBundleID: "com.apple.Safari", policy: policy) == nil)
    }

    @Test("Pausing skips everything")
    func paused() {
        var paused = policy
        paused.isPaused = true
        #expect(PrivacyFilter.skipReason(types: ["public.utf8-plain-text"], sourceBundleID: nil, policy: paused) == .paused)
    }
}

@Suite("CaptureProcessor")
struct CaptureProcessorTests {
    @Test("Text titles use the first non-empty line, collapsed and capped")
    func titles() {
        #expect(CaptureProcessor.title(forText: "\n\n  Ship   v2.3 \nmore") == "Ship v2.3")
        let long = String(repeating: "a", count: 300)
        #expect(CaptureProcessor.title(forText: long).count == CaptureProcessor.maxTitleLength)
    }

    @Test("Hashes depend on kind and content, not on time or source")
    func hashes() {
        let a = TestSupport.textClip("same", at: .distantPast, source: nil)
        let b = TestSupport.textClip("same", at: .now, source: TestSupport.safari)
        #expect(a.contentHash == b.contentHash)
        #expect(a.contentHash != TestSupport.textClip("different").contentHash)
        #expect(CaptureProcessor.hash(kind: .text, "x") != CaptureProcessor.hash(kind: .link, "x"))
    }

    @Test("Images get dimensions and format from the header")
    func image() throws {
        let data = TestSupport.pngData(width: 64, height: 48)
        let clip = try #require(CaptureProcessor.prepare(.image(.init(data: data, typeIdentifier: UTType.png.identifier)), source: nil))
        #expect(clip.kind == .image)
        #expect(clip.image?.pixelWidth == 64)
        #expect(clip.image?.pixelHeight == 48)
        #expect(clip.image?.format == "PNG")
    }

    @Test("Undecodable image data is dropped")
    func badImage() {
        #expect(CaptureProcessor.prepare(.image(.init(data: Data([1, 2, 3]), typeIdentifier: UTType.png.identifier)), source: nil) == nil)
    }

    @Test("Folders and documents are inspected on disk")
    func files() throws {
        let paths = try TestSupport.temporaryPaths()
        let folder = paths.root.appending(path: "Brand Assets", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in ["a.png", "b.png", ".DS_Store"] {
            try Data([0]).write(to: folder.appending(path: name))
        }
        let pdf = paths.root.appending(path: "contract.pdf")
        try Data(count: 2_048).write(to: pdf)

        let folderClip = try #require(CaptureProcessor.prepare(.files([folder]), source: nil))
        #expect(folderClip.kind == .folder)
        #expect(folderClip.file?.itemCount == 2)

        let docClip = try #require(CaptureProcessor.prepare(.files([pdf]), source: nil))
        #expect(docClip.kind == .doc)
        #expect(docClip.file?.byteCount == 2_048)
        #expect(docClip.file?.accent == RGBColor(0xFF453A))

        let multi = try #require(CaptureProcessor.prepare(.files([pdf, folder]), source: nil))
        #expect(multi.title == "contract.pdf and 1 more")
    }
}

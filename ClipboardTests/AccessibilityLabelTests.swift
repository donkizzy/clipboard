import Foundation
import Testing
@testable import Clipboard

@Suite("Accessibility labels")
struct AccessibilityLabelTests {
    private let now = Date(timeIntervalSince1970: 1_795_262_400)

    private func clip(_ index: Int) -> ClipSnapshot {
        DemoSeed.snapshots(now: now)[index]
    }

    @Test("Cards read type, title, source, age and pin state, as in the spec")
    func specExample() {
        var link = clip(1)
        link.isPinned = true
        #expect(link.accessibilityDescription(now: now) == "Link, Framer Motion — layout animations, from Safari, 2 minutes ago, pinned")
    }

    @Test("Unpinned items omit the pin state; code reads as Code")
    func otherKinds() {
        #expect(clip(4).accessibilityDescription(now: now) == "Code, debounce(), from VS Code, 18 minutes ago, pinned")
        #expect(clip(6).accessibilityDescription(now: now) == "Folder, Brand Assets, from Finder, 31 minutes ago")
        #expect(clip(2).accessibilityDescription(now: now) == "Image, Screenshot 2026-07-22 at 10.14.png, from Screenshot, 5 minutes ago")
    }
}

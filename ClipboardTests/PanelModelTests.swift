import Foundation
import Testing
@testable import Clipboard

@MainActor
@Suite("PanelModel")
struct PanelModelTests {
    private let model: PanelModel
    private let store: InMemoryClipStore

    init() {
        let defaults = UserDefaults(suiteName: "PanelModelTests-\(UUID().uuidString)")!
        store = InMemoryClipStore(snapshots: DemoSeed.snapshots())
        model = PanelModel(store: store, preferences: Preferences(defaults: defaults))
    }

    @Test("Selection is clamped to the visible items")
    func clamping() {
        model.moveSelection(by: -1)
        #expect(model.selectedIndex == 0)
        model.select(index: 100)
        #expect(model.selectedIndex == 11)
        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 11)
    }

    @Test("Typing a query resets the selection to the first match")
    func queryResetsSelection() {
        model.select(index: 5)
        model.query = "safari"
        #expect(model.selectedIndex == 0)
        #expect(model.visible.count == 3)
    }

    @Test("Switching filters resets the selection and closes the preview")
    func filterResets() {
        model.select(index: 3)
        model.openPreview()
        model.setFilter(.files)
        #expect(model.selectedIndex == 0)
        #expect(!model.isPreviewOpen)
        #expect(model.visible.allSatisfy { $0.kind.isFile })
    }

    @Test("Deleting the last item keeps a valid selection")
    func deleteLast() {
        model.select(index: 11)
        model.delete()
        #expect(model.visible.count == 11)
        #expect(model.selectedIndex == 10)
        #expect(model.toast?.style == .deleted)
    }

    @Test("Pinning updates counts and the pinned filter")
    func pinning() {
        model.select(index: 1)
        model.togglePin()
        #expect(model.counts[.pinned] == 3)
        model.setFilter(.pinned)
        #expect(model.visible.count == 3)
        model.togglePin()
        #expect(model.counts[.pinned] == 2)
    }

    @Test("Pinning with pinned-on-top keeps the same item selected as it moves")
    func selectionFollowsItem() {
        model.preferences.pinnedOnTop = true
        model.panelWillShow()
        model.select(index: 5)
        let target = model.selected
        model.togglePin()
        #expect(model.selected == target.map { var pinned = $0; pinned.isPinned = true; return pinned })
        #expect(model.selectedIndex == 2) // now the third pinned item, at the top
        model.panelDidHide()
    }

    @Test("A new item arriving doesn't change what's selected")
    func selectionSurvivesInsertions() async {
        model.select(index: 3)
        let target = model.selected?.id
        store.insertForTesting(TestSupport.snapshot("arrived while open"))
        for _ in 0..<50 where model.visible.count != 13 { await Task.yield() }
        #expect(model.selected?.id == target)
        #expect(model.selectedIndex == 4)
    }

    @Test("Unpinning the last pinned item from Quick Look closes the preview")
    func unpinLastPinnedClosesPreview() {
        model.setFilter(.pinned)
        model.togglePin()
        model.openPreview()
        #expect(model.isPreviewOpen)
        model.togglePin()
        #expect(model.visible.isEmpty)
        #expect(!model.isPreviewOpen)
    }

    @Test("Esc closes the preview, then clears the search, then gives up")
    func escapeOrder() {
        model.query = "a"
        model.openPreview()
        #expect(model.handleEscape())
        #expect(!model.isPreviewOpen)
        #expect(model.query == "a")
        #expect(model.handleEscape())
        #expect(model.query.isEmpty)
        #expect(!model.handleEscape())
    }

    @Test("↵ and ⌘↵ hand the selected item to the action handler")
    func copyAndPaste() {
        let handler = RecordingHandler()
        model.actionHandler = handler
        model.select(index: 2)
        model.copySelected()
        model.pasteSelected()
        #expect(handler.copied.map(\.title) == ["Screenshot 2026-07-22 at 10.14.png"])
        #expect(handler.pasted.map(\.title) == ["Screenshot 2026-07-22 at 10.14.png"])
    }

    @Test("Copy does nothing when nothing matches")
    func copyWithNoSelection() {
        let handler = RecordingHandler()
        model.actionHandler = handler
        model.query = "nothing matches this"
        model.copySelected()
        #expect(handler.copied.isEmpty)
    }

    @Test("Opening the panel starts fresh")
    func freshOnShow() {
        model.query = "link"
        model.select(index: 2)
        model.panelWillShow()
        #expect(model.query.isEmpty)
        #expect(model.selectedIndex == 0)
        model.panelDidHide()
    }

    @Test("Pinned-on-top floats pinned items without reordering the rest")
    func pinnedOnTop() {
        model.preferences.pinnedOnTop = true
        model.panelWillShow()
        #expect(model.visible.prefix(2).allSatisfy { $0.isPinned })
        model.panelDidHide()
    }
}

@MainActor
private final class RecordingHandler: PanelActionHandling {
    var copied: [ClipSnapshot] = []
    var pasted: [ClipSnapshot] = []
    func copy(_ clip: ClipSnapshot) { copied.append(clip) }
    func paste(_ clip: ClipSnapshot) { pasted.append(clip) }
}

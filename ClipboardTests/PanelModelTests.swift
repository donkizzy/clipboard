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

    @Test("Copy confirms and asks the panel to close")
    func copyDismisses() {
        var requested: Duration?
        model.onDismissRequest = { requested = $0 }
        model.copySelected()
        #expect(model.toast?.style == .copied)
        #expect(requested == PanelModel.dismissDelayAfterCopy)
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

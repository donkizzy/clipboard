import Foundation

/// Composition root: builds the object graph once at launch.
@MainActor
final class AppEnvironment {
    let preferences: Preferences
    let store: any ClipStore
    let panelModel: PanelModel
    let panelController: PanelController

    init(processInfo: ProcessInfo = .processInfo) {
        preferences = Preferences()
        // M1: the panel always runs on the design's sample data.
        // M3 swaps in the persistent SwiftData store (and `--demo` keeps this one).
        store = InMemoryClipStore(snapshots: DemoSeed.snapshots())
        panelModel = PanelModel(store: store, preferences: preferences)
        panelController = PanelController(model: panelModel)
    }
}

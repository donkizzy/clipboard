import Foundation

/// The intents a card or row can trigger, bundled so leaf views don't hold
/// the whole model (and don't accidentally observe it).
@MainActor
struct ClipActions {
    let select: (ClipSnapshot.ID) -> Void
    let openPreview: (ClipSnapshot.ID) -> Void
    let togglePin: (ClipSnapshot.ID) -> Void
    let delete: (ClipSnapshot.ID) -> Void

    init(model: PanelModel) {
        select = { [weak model] in model?.select($0) }
        openPreview = { [weak model] in model?.openPreview($0) }
        togglePin = { [weak model] in model?.togglePin($0) }
        delete = { [weak model] in model?.delete($0) }
    }
}

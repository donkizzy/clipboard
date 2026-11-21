import Foundation

/// The intents a card or row can trigger, bundled so leaf views don't hold
/// the whole model (and don't accidentally observe it).
@MainActor
struct ClipActions {
    let select: (ClipSnapshot.ID) -> Void
    let openPreview: (ClipSnapshot.ID) -> Void
    let togglePin: (ClipSnapshot.ID) -> Void
    let delete: (ClipSnapshot.ID) -> Void

    /// Clicking an item moves focus to the results (as clicking outside a
    /// text field does on the web), so Space and ⌫ then act on it.
    init(model: PanelModel, focus: SearchFocus) {
        select = { [weak model, weak focus] in
            model?.select($0)
            focus?.blur()
        }
        openPreview = { [weak model, weak focus] in
            model?.openPreview($0)
            focus?.blur()
        }
        togglePin = { [weak model] in model?.togglePin($0) }
        delete = { [weak model] in model?.delete($0) }
    }
}

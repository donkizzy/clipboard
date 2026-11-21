import Observation

/// Calls `onChange` with the new value whenever `value()` changes, for as
/// long as `owner` is alive. A thin loop over `withObservationTracking`,
/// which only fires once per registration.
@MainActor
func observe<Owner: AnyObject & Sendable, Value: Equatable>(
    _ owner: Owner,
    _ value: @escaping @MainActor () -> Value,
    onChange: @escaping @MainActor (Owner, Value) -> Void
) {
    let current = withObservationTracking {
        value()
    } onChange: { [weak owner] in
        // Fires before the change is applied; read the new value next turn.
        Task { @MainActor [weak owner] in
            guard let owner else { return }
            onChange(owner, value())
            observe(owner, value, onChange: onChange)
        }
    }
    _ = current
}

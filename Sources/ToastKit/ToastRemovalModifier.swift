import SwiftUI

private struct ToastRemovalKey: EnvironmentKey {
    static let defaultValue = ToastRemoval.fade
}

public extension EnvironmentValues {
    /// How cards leave when the call that removes them does not say. ``ToastRemoval/fade``
    /// by default.
    var toastRemoval: ToastRemoval {
        get { self[ToastRemovalKey.self] }
        set { self[ToastRemovalKey.self] = newValue }
    }
}

public extension View {
    /// Sets how toasts below this point leave when a removal does not choose its own.
    ///
    /// ```swift
    /// MyScreen()
    ///     .toasts(toasts)
    ///     .toastRemoval(.trail())
    /// ```
    ///
    /// This is the default for everything that passes no `removal:` — a toast that
    /// expires, one dropped for capacity, one dismissed with `dismiss(id:)` and the
    /// original `dismissAll()`. A card the user swipes away or picks an action for keeps
    /// its own exit. With Reduce Motion on, every removal is a cross-fade.
    ///
    /// Like the style and the metrics, it is read from the environment by the stack, so it
    /// goes outside `.toasts(_:)`.
    func toastRemoval(_ removal: ToastRemoval) -> some View {
        environment(\.toastRemoval, removal)
    }
}

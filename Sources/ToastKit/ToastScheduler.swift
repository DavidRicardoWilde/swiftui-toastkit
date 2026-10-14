import Foundation

/// The clock and one-shot timer `ToastCenter` runs its countdown on.
///
/// Injected rather than called directly so `ToastCenterTests` can drive expiry
/// deterministically instead of sleeping for real seconds.
@MainActor
public protocol ToastScheduling: AnyObject {
    /// Now, as the scheduler sees it. `ToastCenter` derives every deadline from this.
    var now: Date { get }

    /// Replaces any pending work with `action`, to run once after `seconds`.
    func schedule(after seconds: TimeInterval, action: @escaping @MainActor () -> Void)

    /// Cancels pending work, if any. Safe to call when nothing is scheduled.
    func cancel()
}

/// The production scheduler: a structured `Task` per countdown.
///
/// `schedule` always cancels first, so at most one countdown is ever in flight —
/// which is what makes the "only the topmost toast is timed" rule hold even when
/// toasts arrive faster than they expire.
@MainActor
public final class ToastTaskScheduler: ToastScheduling {
    private var pending: Task<Void, Never>?

    public init() {}

    public var now: Date { Date() }

    public func schedule(after seconds: TimeInterval, action: @escaping @MainActor () -> Void) {
        cancel()
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        pending = Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    public func cancel() {
        pending?.cancel()
        pending = nil
    }
}

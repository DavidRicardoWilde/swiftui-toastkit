import XCTest
@testable import ToastKit

/// Deterministic stand-in for `ToastTaskScheduler`: the test advances the clock and
/// fires the pending countdown by hand, so the LIFO rules can be asserted without
/// sleeping for real seconds.
@MainActor
final class FakeToastScheduler: ToastScheduling {
    var now = Date(timeIntervalSince1970: 1_000)

    private(set) var pendingInterval: TimeInterval?
    private(set) var cancelCount = 0
    private var pendingAction: (@MainActor () -> Void)?

    func schedule(after seconds: TimeInterval, action: @escaping @MainActor () -> Void) {
        cancel()
        pendingInterval = seconds
        pendingAction = action
    }

    func cancel() {
        if pendingAction != nil { cancelCount += 1 }
        pendingInterval = nil
        pendingAction = nil
    }

    /// Moves the clock forward without firing anything — models a pause.
    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

    /// Advances to the pending deadline and runs it.
    func fire() {
        guard let interval = pendingInterval, let action = pendingAction else {
            return XCTFail("expected a scheduled countdown")
        }
        advance(interval)
        pendingInterval = nil
        pendingAction = nil
        action()
    }
}

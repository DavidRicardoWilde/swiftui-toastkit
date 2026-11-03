import Foundation

/// Decides when a running progress toast speaks.
///
/// Pure bookkeeping, so the rules are tested without a view host or a clock: the caller
/// passes the time in.
///
/// - A milestone is a crossed multiple of `step` below 100%; the outcome has its own
///   announcement.
/// - Milestones are at least `minimumInterval` seconds apart, counted from the last
///   announcement, the start included. One that arrives too soon is *folded* into the next
///   update, which announces the latest value rather than the one that was held back.
/// - Only the front card speaks, and only while the app is active. A milestone crossed
///   while that does not hold is folded in the same way.
struct ToastProgressMilestones: Equatable {
    let step: Double
    let minimumInterval: TimeInterval

    /// How many steps have been announced, or started past.
    private var announcedBoundary = 0
    private var lastAnnouncedAt: Date?

    init(step: Double = 0.25, minimumInterval: TimeInterval = 5) {
        self.step = step.isFinite ? min(1, max(0.01, step)) : 0.25
        self.minimumInterval = max(0, minimumInterval)
    }

    /// Records that the start was announced at `now`, with the bar already at `fraction`.
    mutating func began(at now: Date, fraction: Double?) {
        lastAnnouncedAt = now
        announcedBoundary = boundary(of: fraction) ?? 0
    }

    /// The percent to announce for this update, or `nil` to stay quiet.
    mutating func next(fraction: Double?, now: Date, isFront: Bool, isActive: Bool) -> Int? {
        guard let boundary = boundary(of: fraction) else { return nil }
        // A bar that went backwards, such as a restarted retry, may announce again.
        if boundary < announcedBoundary { announcedBoundary = boundary }
        guard isFront, isActive, boundary > announcedBoundary else { return nil }
        if let last = lastAnnouncedAt, now.timeIntervalSince(last) < minimumInterval { return nil }
        announcedBoundary = boundary
        lastAnnouncedAt = now
        return min(99, Int(((fraction ?? 0) * 100).rounded()))
    }

    /// The number of whole steps in `fraction`, not counting the one that reaches 100%.
    private func boundary(of fraction: Double?) -> Int? {
        guard let fraction, fraction.isFinite else { return nil }
        // The epsilon keeps 0.75 from landing a hair under the third quarter.
        var count = Int((fraction / step + 1e-9).rounded(.down))
        while count > 0, Double(count) * step >= 1 - 1e-9 { count -= 1 }
        return max(0, count)
    }
}

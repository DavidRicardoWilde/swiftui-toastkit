import Foundation
import Observation

/// The single writable source of truth for a stack of toasts, and the owner of its
/// countdown.
///
/// Create one per stack, keep it in `@State`, and hand it to the stack with
/// `.toasts(_:)`. Present from anywhere that can reach it:
///
/// ```swift
/// @State private var toasts = ToastCenter()
///
/// toasts.present(.warning, title: "Low storage", message: "Free up space to keep syncing.")
/// ```
///
/// **LIFO.** `toasts` is ordered oldest-first, so `toasts.last` is the newest and the
/// one the stack draws in front. Exactly one toast is ever timed: the topmost. Three
/// rules follow, and they are what `ToastCenterTests` pins down:
///
/// 1. Presenting a toast makes it topmost, so the countdown *resets* onto the new
///    arrival. The toast it buried keeps its full duration in reserve.
/// 2. When the topmost leaves — expired, swiped or tapped — the one beneath becomes
///    topmost and starts its own timer from the top, not from whatever was left of an
///    earlier run.
/// 3. While the user is touching the stack, or the app is out of the foreground, the
///    countdown is paused, and resumes with the time that was actually left rather
///    than restarting.
///
/// Rule 3 is why the phase machine tracks a deadline instead of a plain "seconds
/// remaining": pausing has to be able to ask the clock how much of the run is gone.
///
/// **Postponed toasts.** A toast swiped into ``ToastAction/later`` — or any action whose
/// effect is ``ToastAction/Effect/postpone`` — leaves the stack and waits in
/// ``postponed``. The stack brings it back the next time it appears, which is the next
/// time the user opens the page it lives on.
///
/// **Batches.** ``dismiss(group:removal:scope:)``, ``dismiss(removal:scope:where:)`` and
/// ``dismissAll(removal:scope:)`` remove any number of toasts as one change: the
/// countdown is reconciled once, after all of them are gone, and never waits for the
/// removal animation. A card the user is holding on its action track when code removes
/// it leaves at once, and its hold is cancelled.
@MainActor
@Observable
public final class ToastCenter {

    /// Oldest first. The view reverses depth from this, so `last` renders in front.
    public private(set) var toasts: [ToastMessage] = []

    /// Toasts set aside by a postpone action, oldest first, waiting to come back. See
    /// ``postpone(id:)`` and ``restorePostponed()``.
    public private(set) var postponed: [ToastMessage] = []

    /// True while a finger is down or a fling is playing out. Freezes the countdown so
    /// a toast cannot vanish out from under the gesture acting on it.
    ///
    /// Mutated through `setInteracting(_:)` rather than directly: `@Observable` and
    /// `didSet` do not compose reliably, and the countdown has to be reconciled on
    /// every edge.
    public private(set) var isInteracting: Bool = false

    /// True while the app is not in the foreground. Freezes the countdown like a finger
    /// on the stack does, so a toast shown just before the user switches away is still
    /// there when they come back.
    ///
    /// Mutated through `setSuspended(_:)`, for the same reason as `isInteracting`.
    public private(set) var isSuspended: Bool = false

    /// Seconds a toast with ``ToastDuration/automatic`` stays up. Zero or less makes
    /// such toasts wait to be dismissed.
    public let defaultDuration: TimeInterval

    /// How many cards are drawn before the rest are hidden behind the stack.
    public let visibleDepth: Int

    /// Beyond this, toasts are dropped outright, so a burst cannot grow an unbounded
    /// backlog the user has to swipe through one by one. Postponed toasts are capped at
    /// the same number.
    ///
    /// The oldest *timed* toasts go first. A persistent toast is one the user has to
    /// acknowledge, so a burst of routine notices must not silently push it out; only
    /// when everything left is persistent does the oldest of those go. The arrival
    /// itself is never dropped.
    public let capacity: Int

    /// Cards that have left `toasts` and are still being drawn on their way out. The
    /// stack draws a stand-in for each and reports back through `finishDeparture(token:)`.
    private(set) var departures: [ToastDeparture] = []

    /// The latest batch removal, for the stack to announce to VoiceOver. The serial
    /// changes on every batch, so two batches of the same size are both announced.
    private(set) var batchAnnouncement: ToastBatchAnnouncement?

    /// Cards running their own exit — a swipe's fling, or a track action's drop. They
    /// are removed with a plain fade, and get no stand-in.
    private(set) var ownExitIDs: Set<UUID> = []

    /// The card lifted onto its action track, as the stack reports it.
    @ObservationIgnored private var liftedToastID: UUID?
    @ObservationIgnored private var announcementSerial = 0

    /// A departure older than this has long finished, whatever the view reported.
    private static let departureLifetime: TimeInterval = 5

    private let scheduler: ToastScheduling
    private var phase: Phase = .idle

    /// Which toast the countdown belongs to, and where that countdown stands.
    private enum Phase {
        case idle
        case running(id: UUID, deadline: Date)
        case paused(id: UUID, remaining: TimeInterval)

        var toastID: UUID? {
            switch self {
            case .idle: nil
            case .running(let id, _), .paused(let id, _): id
            }
        }
    }

    /// - Parameters:
    ///   - scheduler: The clock the countdown runs on. `nil` in production; tests
    ///     inject a fake. It cannot default to `ToastTaskScheduler()` directly —
    ///     default arguments are evaluated in a nonisolated context, which cannot reach
    ///     a `@MainActor` initialiser.
    ///   - defaultDuration: Seconds for toasts presented with
    ///     ``ToastDuration/automatic``. Four by default.
    ///   - visibleDepth: Cards drawn at once; the rest wait behind. At least one.
    ///   - capacity: Most toasts held at once. At least one.
    public init(
        scheduler: ToastScheduling? = nil,
        defaultDuration: TimeInterval = ToastDuration.defaultSeconds,
        visibleDepth: Int = 3,
        capacity: Int = 5
    ) {
        self.scheduler = scheduler ?? ToastTaskScheduler()
        self.defaultDuration = defaultDuration
        self.visibleDepth = max(1, visibleDepth)
        self.capacity = max(1, capacity)
    }

    // MARK: - Reading

    /// The toast being timed and drawn in front, if any.
    public var topmost: ToastMessage? { toasts.last }

    /// Depth of `toast` measured from the front: 0 is topmost, 1 sits behind it.
    /// `nil` for a toast that is not in the stack.
    public func depth(of toast: ToastMessage) -> Int? {
        guard let index = toasts.firstIndex(where: { $0.id == toast.id }) else { return nil }
        return toasts.count - 1 - index
    }

    /// Seconds `toast` stays up once topmost, or `nil` when it waits to be dismissed.
    public func displaySeconds(for toast: ToastMessage) -> TimeInterval? {
        toast.duration.resolved(defaultSeconds: defaultDuration)
    }

    // MARK: - Presenting

    /// Pushes `toast` to the front of the stack and hands it the countdown.
    ///
    /// Re-presenting an id already in the stack moves it to the front rather than
    /// duplicating it, so a repeated notice refreshes instead of piling up. Presenting
    /// an id that was postponed takes it out of ``postponed``.
    public func present(_ toast: ToastMessage) {
        pruneTransientState()
        toasts.removeAll { $0.id == toast.id }
        postponed.removeAll { $0.id == toast.id }
        // A stand-in and a live card with one id must never be drawn together.
        if departures.contains(where: { $0.toast.id == toast.id }) {
            departures.removeAll { $0.toast.id == toast.id }
        }
        if ownExitIDs.contains(toast.id) { ownExitIDs.remove(toast.id) }
        toasts.append(toast)
        dropOverflow()
        reconcile()
    }

    /// Convenience for the common call site, which has copy and a role but no id.
    public func present(
        _ status: ToastMessage.Status = .normal,
        title: String,
        message: String? = nil,
        icon: ToastIcon? = nil,
        duration: ToastDuration = .automatic,
        tapAction: ToastAction? = nil,
        swipeActions: ToastSwipeActions = .standard
    ) {
        present(ToastMessage(
            status: status,
            title: title,
            message: message,
            icon: icon,
            duration: duration,
            tapAction: tapAction,
            swipeActions: swipeActions
        ))
    }

    /// Like ``present(_:title:message:icon:duration:tapAction:swipeActions:)``, for a
    /// toast that belongs to `group`. Presenting never replaces another toast in the same
    /// group; use the group to dismiss them together with
    /// ``dismiss(group:removal:scope:)``.
    public func present(
        _ status: ToastMessage.Status = .normal,
        title: String,
        message: String? = nil,
        icon: ToastIcon? = nil,
        duration: ToastDuration = .automatic,
        tapAction: ToastAction? = nil,
        swipeActions: ToastSwipeActions = .standard,
        group: ToastGroup
    ) {
        present(ToastMessage(
            status: status,
            title: title,
            message: message,
            icon: icon,
            duration: duration,
            tapAction: tapAction,
            swipeActions: swipeActions,
            group: group
        ))
    }

    // MARK: - Dismissing

    /// Removes one toast, whether it is showing or postponed. Dismissing a buried card
    /// is allowed and leaves the topmost's countdown untouched.
    public func dismiss(id: UUID) {
        remove(where: { $0.id == id }, scope: .everywhere, removal: nil, announces: false)
    }

    public func dismissTopmost() {
        guard let topmost else { return }
        dismiss(id: topmost.id)
    }

    /// Removes every toast on screen. Postponed toasts stay postponed — clear those with
    /// ``discardPostponed()``, or use ``dismissAll(removal:scope:)``.
    ///
    /// VoiceOver announces how many notifications were dismissed.
    public func dismissAll() {
        remove(where: { _ in true }, scope: .onScreen, removal: nil, announces: true)
    }

    /// Removes every toast in `scope`, all as one change.
    ///
    /// - Parameters:
    ///   - removal: How the cards leave. `nil` uses the stack's default, set with
    ///     `toastRemoval(_:)` and ``ToastRemoval/fade`` unless changed.
    ///   - scope: Which toasts to reach. On screen only by default, like ``dismissAll()``.
    /// - Returns: How many toasts were removed, postponed ones included.
    @discardableResult
    public func dismissAll(removal: ToastRemoval?, scope: ToastDismissalScope = .onScreen) -> Int {
        remove(where: { _ in true }, scope: scope, removal: removal, announces: true)
    }

    /// Removes every toast presented with `group`, all as one change. Toasts without a
    /// group never match.
    ///
    /// - Parameters:
    ///   - group: The group to clear.
    ///   - removal: How the cards leave. `nil` uses the stack's default.
    ///   - scope: Which toasts to reach. Everywhere by default, so a postponed toast of
    ///     the group does not come back later.
    /// - Returns: How many toasts were removed, postponed ones included.
    @discardableResult
    public func dismiss(
        group: ToastGroup,
        removal: ToastRemoval? = nil,
        scope: ToastDismissalScope = .everywhere
    ) -> Int {
        remove(where: { $0.group == group }, scope: scope, removal: removal, announces: true)
    }

    /// Removes every toast `shouldDismiss` accepts, all as one change.
    ///
    /// ```swift
    /// toasts.dismiss(removal: .trail()) { $0.status == .error }
    /// ```
    ///
    /// - Parameters:
    ///   - removal: How the cards leave. `nil` uses the stack's default.
    ///   - scope: Which toasts to reach. Everywhere by default.
    ///   - shouldDismiss: Called once for each toast in scope.
    /// - Returns: How many toasts were removed, postponed ones included.
    @discardableResult
    public func dismiss(
        removal: ToastRemoval? = nil,
        scope: ToastDismissalScope = .everywhere,
        where shouldDismiss: (ToastMessage) -> Bool
    ) -> Int {
        remove(where: shouldDismiss, scope: scope, removal: removal, announces: true)
    }

    /// The one path every removal takes.
    ///
    /// Matching toasts all leave in a single change and the countdown is reconciled once,
    /// afterwards, so a batch never hands the countdown to a toast that is about to go.
    /// The animation is none of its business: the next toast is timed straight away.
    @discardableResult
    private func remove(
        where shouldRemove: (ToastMessage) -> Bool,
        scope: ToastDismissalScope,
        removal: ToastRemoval?,
        announces: Bool
    ) -> Int {
        pruneTransientState()

        var removedCount = 0
        if scope.includesPostponed {
            let before = postponed.count
            postponed.removeAll(where: shouldRemove)
            removedCount += before - postponed.count
        }
        guard scope.includesOnScreen else { return removedCount }

        let matching = Set(toasts.filter(shouldRemove).map(\.id))
        guard !matching.isEmpty else { return removedCount }

        // A lifted card is removed at once, and so are the cards behind it, which are
        // already hidden while it rides its track: no stand-ins for any of them.
        let liftedWasRemoved = liftedToastID.map { matching.contains($0) } ?? false
        recordDepartures(removing: matching, from: toasts, removal: removal)
        toasts.removeAll { matching.contains($0.id) }

        if liftedWasRemoved {
            // Its hold can never be released by the card now.
            liftedToastID = nil
            isInteracting = false
        }
        releaseInteractionIfEmpty()
        reconcile()

        if announces {
            announcementSerial += 1
            batchAnnouncement = ToastBatchAnnouncement(count: matching.count, serial: announcementSerial)
        }
        return removedCount + matching.count
    }

    // MARK: - Postponing

    /// Takes a toast off screen and keeps it in ``postponed`` until
    /// ``restorePostponed()``, which the stack calls each time it appears. A no-op for an
    /// id that is not showing.
    ///
    /// Postponed toasts live as long as this center. To carry them across launches, read
    /// ``postponed`` and present them again yourself.
    public func postpone(id: UUID) {
        guard let toast = toasts.first(where: { $0.id == id }) else { return }
        pruneTransientState()
        recordDepartures(removing: [id], from: toasts, removal: nil)
        toasts.removeAll { $0.id == id }
        postponed.removeAll { $0.id == id }
        postponed.append(toast)
        if postponed.count > capacity {
            postponed.removeFirst(postponed.count - capacity)
        }
        releaseInteractionIfEmpty()
        reconcile()
    }

    /// Presents every postponed toast again, oldest first, so the one postponed last
    /// comes back in front with a fresh countdown.
    public func restorePostponed() {
        guard !postponed.isEmpty else { return }
        let returning = postponed
        postponed.removeAll()
        for toast in returning {
            present(toast)
        }
    }

    /// Forgets every postponed toast without showing it.
    public func discardPostponed() {
        postponed.removeAll()
    }

    // MARK: - Pausing

    /// Pauses (`true`) or resumes (`false`) the countdown. Idempotent.
    public func setInteracting(_ interacting: Bool) {
        guard interacting != isInteracting else { return }
        isInteracting = interacting
        reconcile()
    }

    /// Pauses (`true`) or resumes (`false`) the countdown while the app is out of the
    /// foreground. Independent of `setInteracting(_:)`: the countdown runs only when
    /// neither holds it. Idempotent.
    public func setSuspended(_ suspended: Bool) {
        guard suspended != isSuspended else { return }
        isSuspended = suspended
        reconcile()
    }

    // MARK: - Capacity

    private func isPersistent(_ toast: ToastMessage) -> Bool {
        displaySeconds(for: toast) == nil
    }

    /// Trims the stack back to `capacity`: oldest timed toasts first, then — only if
    /// everything left is persistent — the oldest of those. The newest toast, the one
    /// just presented, always stays.
    private func dropOverflow() {
        var excess = toasts.count - capacity
        guard excess > 0, let arrival = toasts.last?.id else { return }

        var kept: [ToastMessage] = []
        for toast in toasts {
            if excess > 0, !isPersistent(toast), toast.id != arrival {
                excess -= 1
            } else {
                kept.append(toast)
            }
        }
        // `kept` still ends with the arrival and holds `capacity + excess` toasts, so
        // this never reaches it.
        kept.removeFirst(excess)
        let keptIDs = Set(kept.map(\.id))
        let dropped = Set(toasts.map(\.id)).subtracting(keptIDs)
        // Planned against the stack as it was last drawn, before the arrival was added.
        recordDepartures(removing: dropped, from: Array(toasts.dropLast()), removal: nil)
        toasts = kept
    }

    // MARK: - Departures

    /// Adds a departure for each visible card of `stack` that `ids` takes, unless it is
    /// animating its own exit. Adds none while a card is lifted: that card leaves at
    /// once and the ones behind it are already hidden.
    private func recordDepartures(removing ids: Set<UUID>, from stack: [ToastMessage], removal: ToastRemoval?) {
        guard liftedToastID == nil, !ids.isEmpty else { return }
        let added = ToastDeparture.plan(
            removing: ids,
            from: stack,
            visibleDepth: visibleDepth,
            removal: removal,
            excluding: ownExitIDs,
            at: scheduler.now
        )
        guard !added.isEmpty else { return }
        departures.append(contentsOf: added)
        trimDepartures()
    }

    /// Keeps the newest `capacity + visibleDepth` departures.
    private func trimDepartures() {
        let limit = capacity + visibleDepth
        if departures.count > limit {
            departures.removeFirst(departures.count - limit)
        }
    }

    /// Forgets what has outlived its use: departures the view never reported finished,
    /// the oldest beyond a bound, and own-exit marks for toasts that are gone.
    private func pruneTransientState() {
        // Each write is guarded: assigning to an observed property redraws the stack even
        // when nothing changed.
        let now = scheduler.now
        if departures.contains(where: { now.timeIntervalSince($0.departedAt) > Self.departureLifetime }) {
            departures.removeAll { now.timeIntervalSince($0.departedAt) > Self.departureLifetime }
        }
        trimDepartures()
        if !ownExitIDs.isEmpty {
            let showing = Set(toasts.map(\.id))
            let stale = ownExitIDs.subtracting(showing)
            if !stale.isEmpty { ownExitIDs.subtract(stale) }
        }
        // A lifted card that is no longer in the stack can never report being put back.
        if let lifted = liftedToastID, !toasts.contains(where: { $0.id == lifted }) {
            liftedToastID = nil
        }
    }

    // MARK: - Reported by the stack

    /// The stack reports the card lifted onto its action track, or `nil` when none is.
    func setLifted(_ id: UUID?) {
        liftedToastID = id
    }

    /// A card is animating its own exit, so removing it needs no stand-in.
    func beginOwnExit(id: UUID) {
        guard toasts.contains(where: { $0.id == id }) else { return }
        ownExitIDs.insert(id)
    }

    /// A stand-in finished its animation.
    func finishDeparture(token: UUID) {
        guard departures.contains(where: { $0.token == token }) else { return }
        departures.removeAll { $0.token == token }
    }

    /// Drops every stand-in, so a page opened again never replays old exits.
    func clearDepartures() {
        guard !departures.isEmpty else { return }
        departures.removeAll()
    }

    // MARK: - Interaction

    /// An empty stack has no card left to touch, so it cannot still be interacting.
    ///
    /// The card lowers the flag when its gesture ends, but a card removed mid-drag —
    /// `dismissAll()` while a finger is down — never gets that far. Without this the
    /// flag would stay raised and every later toast would wait forever for a lift.
    private func releaseInteractionIfEmpty() {
        if toasts.isEmpty { isInteracting = false }
    }

    // MARK: - Countdown

    /// A finger on the stack and an app out of the foreground both hold the countdown.
    private var isPaused: Bool { isInteracting || isSuspended }

    /// Brings the timer in line with `(topmost, isPaused)`.
    ///
    /// Idempotent by design — every mutation calls it, and calling it twice for an
    /// unchanged stack must not extend a running countdown. That is what the
    /// `where id == topmost.id` guards buy: a phase already describing the current
    /// topmost is left alone unless the pause state flipped.
    private func reconcile() {
        guard let topmost, let seconds = displaySeconds(for: topmost) else {
            transition(to: .idle)
            return
        }

        switch phase {
        case .running(let id, let deadline) where id == topmost.id:
            guard isPaused else { return }
            transition(to: .paused(id: id, remaining: max(0, deadline.timeIntervalSince(scheduler.now))))

        case .paused(let id, let remaining) where id == topmost.id:
            guard !isPaused else { return }
            transition(to: .running(id: id, deadline: scheduler.now.addingTimeInterval(remaining)))

        case .idle, .running, .paused:
            // A different toast is topmost now — it gets its full duration, whether or
            // not the one it replaced had time left.
            transition(
                to: isPaused
                    ? .paused(id: topmost.id, remaining: seconds)
                    : .running(id: topmost.id, deadline: scheduler.now.addingTimeInterval(seconds))
            )
        }
    }

    private func transition(to newPhase: Phase) {
        phase = newPhase
        scheduler.cancel()
        guard case .running(let id, let deadline) = newPhase else { return }
        scheduler.schedule(after: max(0, deadline.timeIntervalSince(scheduler.now))) { [weak self] in
            self?.expire(id)
        }
    }

    /// Fired by the scheduler. Guarded against a toast that stopped being topmost
    /// between the countdown starting and the timer landing.
    private func expire(_ id: UUID) {
        guard topmost?.id == id else { return }
        dismiss(id: id)
    }
}

#if DEBUG
extension ToastCenter {
    /// Id of the toast currently holding the countdown — `nil` when nothing is timed.
    /// Exists for `ToastCenterTests`; the timer is otherwise entirely internal.
    var timedToastID: UUID? { phase.toastID }
}
#endif

import Foundation

/// A card that has left the model but is still being drawn, on its way out.
///
/// ``ToastCenter`` records one for each visible card a removal takes, and the stack
/// draws a stand-in for it until the animation finishes. Plain data, so the ordering
/// and bookkeeping are tested without a view host.
struct ToastDeparture: Identifiable, Equatable {
    let toast: ToastMessage
    /// Names this departure alone. A toast dismissed, presented again and dismissed again
    /// has two departures with one toast id; the first one finishing must not end the second.
    let token = UUID()
    /// Depth the card had in the stack just before it left. 0 is the front.
    let depth: Int
    /// Position among the cards leaving together, front card first.
    let order: Int
    /// How many cards leave together.
    let batchCount: Int
    /// What was asked for. `nil` means the stack's default.
    let removal: ToastRemoval?
    let departedAt: Date

    var id: UUID { token }

    /// The departures for the cards of `toasts` that `removing` takes.
    ///
    /// Walks the stack front to back and keeps only cards that are being removed, are
    /// visible (`depth < visibleDepth`) and are not in `excluding` — the ones already
    /// animating their own exit.
    ///
    /// - Parameter toasts: The stack as the model holds it, oldest first.
    static func plan(
        removing: Set<UUID>,
        from toasts: [ToastMessage],
        visibleDepth: Int,
        removal: ToastRemoval?,
        excluding: Set<UUID>,
        at date: Date
    ) -> [ToastDeparture] {
        var leaving: [(toast: ToastMessage, depth: Int)] = []
        for (index, toast) in toasts.enumerated().reversed() {
            let depth = toasts.count - 1 - index
            guard depth < visibleDepth, removing.contains(toast.id), !excluding.contains(toast.id) else { continue }
            leaving.append((toast, depth))
        }
        return leaving.enumerated().map { order, entry in
            ToastDeparture(
                toast: entry.toast,
                depth: entry.depth,
                order: order,
                batchCount: leaving.count,
                removal: removal,
                departedAt: date
            )
        }
    }
}

/// A batch removal the stack should announce to VoiceOver. The serial changes on every
/// batch, so two batches of the same size are both announced.
struct ToastBatchAnnouncement: Equatable {
    let count: Int
    let serial: Int
}

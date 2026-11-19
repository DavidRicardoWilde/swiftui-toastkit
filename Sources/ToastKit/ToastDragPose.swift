import SwiftUI

/// Where a card sits while a finger drags it: the numbers the card and its stand-in share.
///
/// Plain values, so a test can pin the formulas without a view host, and so a card that
/// is removed mid-drag can hand its pose to the stand-in that takes over.
struct ToastDragPose: Equatable {
    /// Horizontal offset, from the finger's travel.
    let x: CGFloat
    /// Vertical offset from an up or down swipe, which goes straight.
    let y: CGFloat
    /// Vertical sag: a sideways swipe bends gently toward the stack's edge (y ≈ x² ÷ 1800,
    /// at most 160 pt), so a throw reads as a swing. Flat under Reduce Motion.
    let sag: CGFloat
    /// Tilt following a sideways drag, mirrored for a top stack. None under Reduce Motion.
    let rotationDegrees: Double
    /// The card edge the tilt pivots off: the bottom of a bottom stack, the top of a top
    /// one, so a top stack swings as the mirror image of a bottom one.
    let rotationAnchor: UnitPoint
    /// Fades with travel in any direction, to no less than 35%.
    let opacity: Double

    init(dragX: CGFloat, dragY: CGFloat = 0, curve: CGFloat, reduceMotion: Bool) {
        x = dragX
        y = dragY
        sag = reduceMotion ? 0 : curve * min(dragX * dragX / 1_800, 160)
        rotationDegrees = reduceMotion ? 0 : Double(curve * dragX) / 36
        rotationAnchor = curve > 0 ? .bottom : .top
        opacity = 1 - min(Double(abs(dragX) + abs(dragY)) / 240, 0.65)
    }

    /// A card that is not being dragged.
    static let rest = ToastDragPose(dragX: 0, curve: 1, reduceMotion: false)
}

/// Where each card in a stack is being dragged to, by toast id.
///
/// A plain reference box in the environment rather than a preference or observable state:
/// the card writes it on every frame of a drag, and nothing should redraw because of it.
/// The stack reads it once, when a stand-in takes over a card removed mid-drag.
@MainActor
final class ToastDragPoseRegistry {
    private var poses: [UUID: ToastDragPose] = [:]

    func set(_ pose: ToastDragPose, for id: UUID) {
        poses[id] = pose
    }

    func pose(for id: UUID) -> ToastDragPose {
        poses[id] ?? .rest
    }

    func clear(_ id: UUID) {
        poses[id] = nil
    }
}

private struct ToastDragPoseRegistryKey: EnvironmentKey {
    static let defaultValue: ToastDragPoseRegistry? = nil
}

extension EnvironmentValues {
    /// `nil` outside a stack, where nothing needs a card's drag pose.
    var toastDragPoses: ToastDragPoseRegistry? {
        get { self[ToastDragPoseRegistryKey.self] }
        set { self[ToastDragPoseRegistryKey.self] = newValue }
    }
}

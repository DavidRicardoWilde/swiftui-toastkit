import SwiftUI

/// Where a card sits while a finger drags it: the numbers the card and its stand-in share.
///
/// Plain values, so a test can pin the formulas without a view host, and so a card that
/// is removed mid-drag can hand its pose to the stand-in that takes over.
struct ToastDragPose: Equatable {
    /// Horizontal offset, from the finger's travel.
    let x: CGFloat
    /// Vertical sag: the swipe bends gently toward the stack's edge (y ≈ x² ÷ 1800, at
    /// most 160 pt), so a throw reads as a swing. Flat under Reduce Motion.
    let sag: CGFloat
    /// Tilt, pivoting off the card's bottom edge. None under Reduce Motion.
    let rotationDegrees: Double
    /// Fades with travel in either direction, to no less than 35%.
    let opacity: Double

    init(dragX: CGFloat, curve: CGFloat, reduceMotion: Bool) {
        x = dragX
        sag = reduceMotion ? 0 : curve * min(dragX * dragX / 1_800, 160)
        rotationDegrees = reduceMotion ? 0 : Double(dragX) / 36
        opacity = 1 - min(Double(abs(dragX)) / 240, 0.65)
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

import Observation
import SwiftUI

// MARK: - Public API

public extension View {

    /// Marks this view as covering part of the screen, so toast stacks keep clear of it.
    ///
    /// The safe area already covers system bars — a `TabView`'s tab bar, its bottom
    /// accessory in any placement, the home indicator — so those need nothing. Mark the
    /// things the safe area does not know about: a custom tab bar drawn in a `ZStack`, a
    /// floating player, a bar you add with `.safeAreaInset` outside the view that hosts
    /// the stack.
    ///
    /// A stack measures each marked view wherever it is and lifts itself just clear of
    /// it, following it as it grows, shrinks, moves or goes away. Only views on the
    /// stack's own side count: a bottom stack ignores a marked toolbar at the top.
    ///
    /// ```swift
    /// ZStack(alignment: .bottom) {
    ///     content
    ///     MyTabBar()
    ///         .toastObstruction()
    /// }
    /// .toasts(toasts)
    /// ```
    ///
    /// The stack sees views marked inside the view `.toasts(_:)` is applied to. For one
    /// marked elsewhere — a bar hosted above a `NavigationStack`, say, while the stack
    /// lives in a page inside it — apply `toastObstructionScope()` to a view that
    /// contains both.
    ///
    /// - Parameter isActive: Pass `false` to stop counting the view without removing
    ///   the modifier, such as while a bar is collapsed into something the safe area
    ///   already covers.
    func toastObstruction(_ isActive: Bool = true) -> some View {
        modifier(ToastObstructionMarker(isActive: isActive))
    }

    /// Lets stacks inside this view keep clear of views marked with
    /// `toastObstruction()` anywhere else inside it.
    ///
    /// Only needed when a marked view and a stack are not one inside the other. Apply it
    /// to their nearest common container; it is harmless higher up.
    ///
    /// ```swift
    /// TabView { … }
    ///     .toastObstructionScope()      // pages' stacks see the bar below
    /// ```
    func toastObstructionScope() -> some View {
        modifier(ToastObstructionScope())
    }
}

// MARK: - Registry

/// The frames of the marked views in one scope, in global coordinates.
///
/// A reference type in the environment rather than a preference, because a marked view
/// is often beside or above the stack rather than inside it, where a preference cannot
/// reach.
@MainActor
@Observable
final class ToastObstructionRegistry {
    private(set) var frames: [UUID: CGRect] = [:]

    func set(_ frame: CGRect?, for id: UUID) {
        guard frames[id] != frame else { return }
        frames[id] = frame
    }
}

private struct ToastObstructionRegistryKey: EnvironmentKey {
    static let defaultValue: ToastObstructionRegistry? = nil
}

extension EnvironmentValues {
    /// The nearest scope's registry, if any.
    var toastObstructions: ToastObstructionRegistry? {
        get { self[ToastObstructionRegistryKey.self] }
        set { self[ToastObstructionRegistryKey.self] = newValue }
    }
}

struct ToastObstructionScope: ViewModifier {
    @State private var registry = ToastObstructionRegistry()

    func body(content: Content) -> some View {
        content.environment(\.toastObstructions, registry)
    }
}

/// Reports a view's frame to the nearest registry while it is on screen.
private struct ToastObstructionMarker: ViewModifier {
    let isActive: Bool

    @Environment(\.toastObstructions) private var registry
    @State private var id = UUID()
    @State private var frame: CGRect?
    @State private var isOnScreen = false

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newFrame in
                frame = newFrame
                publish(frame: newFrame, onScreen: isOnScreen, active: isActive)
            }
            .onAppear {
                isOnScreen = true
                publish(frame: frame, onScreen: true, active: isActive)
            }
            .onDisappear {
                isOnScreen = false
                publish(frame: frame, onScreen: false, active: isActive)
            }
            .onChange(of: isActive) { _, active in
                publish(frame: frame, onScreen: isOnScreen, active: active)
            }
    }

    private func publish(frame: CGRect?, onScreen: Bool, active: Bool) {
        registry?.set(onScreen && active ? frame : nil, for: id)
    }
}

// MARK: - Layout

/// How far a stack moves off its edge to clear the marked views. Pure, so
/// `ToastObstructionLayoutTests` can pin it.
enum ToastObstructionLayout {

    /// - Parameters:
    ///   - stack: The region the stack was given, in global coordinates, before any
    ///     lift.
    ///   - anchor: The edge the stack hangs from.
    ///   - obstructions: Marked views' frames, in the same coordinates.
    /// - Returns: The distance to move away from the edge: zero when nothing on the
    ///   stack's side reaches into it, never more than the stack's own height.
    static func lift(
        for stack: CGRect,
        anchor: ToastPlacement.Anchor,
        obstructions: [CGRect]
    ) -> CGFloat {
        guard stack.width > 0, stack.height > 0 else { return 0 }
        var lift: CGFloat = 0
        for frame in obstructions {
            guard frame.width > 0, frame.height > 0,
                  frame.minX < stack.maxX, frame.maxX > stack.minX else { continue }
            switch anchor {
            case .bottom:
                // Only what sits toward the stack's own edge; a bar at the top of the
                // screen is not in a bottom stack's way.
                guard frame.midY > stack.midY else { continue }
                lift = max(lift, stack.maxY - frame.minY)
            case .top:
                guard frame.midY < stack.midY else { continue }
                lift = max(lift, frame.maxY - stack.minY)
            }
        }
        return min(max(0, lift), stack.height)
    }
}

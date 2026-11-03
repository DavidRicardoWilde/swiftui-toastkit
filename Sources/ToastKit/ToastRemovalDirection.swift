import CoreGraphics
import Foundation

/// Which way departing cards travel.
///
/// ```swift
/// toasts.dismissAll(removal: .slide(.trailing))
/// toasts.dismiss(group: "upload", removal: .trail(.degrees(-90)))   // straight up
/// ```
///
/// ``leading`` and ``trailing`` follow the layout direction; ``degrees(_:)`` and
/// ``vector(dx:dy:)`` are physical and are never mirrored. Cards travel far enough to
/// leave the region the stack was given.
public struct ToastRemovalDirection: Hashable, Sendable {

    enum Storage: Hashable, Sendable {
        case inPlace
        case towardAnchor
        case awayFromAnchor
        case top
        case bottom
        case leading
        case trailing
        case degrees(Double)
        case vector(dx: Double, dy: Double)
    }

    let storage: Storage

    private init(_ storage: Storage) {
        self.storage = storage
    }

    /// No travel: the card fades where it stands.
    public static let inPlace = ToastRemovalDirection(.inPlace)
    /// Toward the edge the stack hangs from.
    public static let towardAnchor = ToastRemovalDirection(.towardAnchor)
    /// Away from the edge the stack hangs from.
    public static let awayFromAnchor = ToastRemovalDirection(.awayFromAnchor)
    /// Up the screen.
    public static let top = ToastRemovalDirection(.top)
    /// Down the screen.
    public static let bottom = ToastRemovalDirection(.bottom)
    /// Toward the leading edge: left in a left-to-right layout.
    public static let leading = ToastRemovalDirection(.leading)
    /// Toward the trailing edge: right in a left-to-right layout.
    public static let trailing = ToastRemovalDirection(.trailing)

    /// An angle in degrees. 0° points right and angles increase clockwise on screen, so
    /// 90° points down and −90° points up. Not mirrored in a right-to-left layout.
    /// A value that is not finite means ``inPlace``.
    public static func degrees(_ degrees: Double) -> ToastRemovalDirection {
        guard degrees.isFinite else { return .inPlace }
        return ToastRemovalDirection(.degrees(degrees))
    }

    /// A direction given as a vector, in screen space where y grows downward. It is
    /// normalised, so only its direction matters; a zero vector means no travel. Not
    /// mirrored in a right-to-left layout. A component that is not finite means
    /// ``inPlace``.
    public static func vector(dx: Double, dy: Double) -> ToastRemovalDirection {
        guard dx.isFinite, dy.isFinite else { return .inPlace }
        return ToastRemovalDirection(.vector(dx: dx, dy: dy))
    }

    /// The unit vector the card travels along, in screen space, or `nil` for no travel.
    func unitVector(anchor: ToastPlacement.Anchor, isRightToLeft: Bool) -> CGVector? {
        let raw: (dx: Double, dy: Double)
        switch storage {
        case .inPlace:
            return nil
        case .towardAnchor:
            raw = (0, anchor == .bottom ? 1 : -1)
        case .awayFromAnchor:
            raw = (0, anchor == .bottom ? -1 : 1)
        case .top:
            raw = (0, -1)
        case .bottom:
            raw = (0, 1)
        case .leading:
            raw = (isRightToLeft ? 1 : -1, 0)
        case .trailing:
            raw = (isRightToLeft ? -1 : 1, 0)
        case .degrees(let degrees):
            let radians = degrees * Double.pi / 180
            raw = (cos(radians), sin(radians))
        case .vector(let dx, let dy):
            let length = hypot(dx, dy)
            guard length > 0, length.isFinite else { return nil }
            raw = (dx / length, dy / length)
        }
        return CGVector(dx: Self.snapped(raw.dx), dy: Self.snapped(raw.dy))
    }

    /// Rounding error from `cos`/`sin` must not leave a stray 6e-17 on an axis, so a
    /// right angle is exactly axis-aligned.
    private static func snapped(_ component: Double) -> CGFloat {
        abs(component) < 1e-9 ? 0 : CGFloat(component)
    }
}

/// How far a card travels to leave the region the stack was given.
enum ToastDeparturePath {

    /// What an unmeasured region falls back to: the same as the swipe's exit distance.
    static let fallbackDistance: CGFloat = 1_400

    /// The exact travel along `along` for `card` to clear `region`, taking the smallest
    /// result over the axes that move, plus `margin` for shadow and blur. Zero when the
    /// card does not move, and `fallbackDistance` when the region has not been measured.
    static func distance(
        card: CGRect,
        region: CGRect,
        along: CGVector?,
        margin: CGFloat = 40
    ) -> CGFloat {
        guard let along else { return 0 }
        guard region != .zero else { return fallbackDistance }

        var best: CGFloat?
        if along.dx > 0 {
            best = shortest(best, (region.maxX - card.minX) / along.dx)
        } else if along.dx < 0 {
            best = shortest(best, (card.maxX - region.minX) / -along.dx)
        }
        if along.dy > 0 {
            best = shortest(best, (region.maxY - card.minY) / along.dy)
        } else if along.dy < 0 {
            best = shortest(best, (card.maxY - region.minY) / -along.dy)
        }
        guard let best else { return 0 }
        return max(0, best) + margin
    }

    private static func shortest(_ current: CGFloat?, _ candidate: CGFloat) -> CGFloat {
        guard let current else { return candidate }
        return min(current, candidate)
    }
}

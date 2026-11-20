import Foundation

/// A caller-defined kind of toast, used to dismiss related toasts together.
///
/// A group is just a name — `"sync"`, or `"upload:\(id)"` for one per item — so it can be
/// built from a string literal. Presenting a toast never replaces another in the same
/// group; the group only matters when dismissing:
///
/// ```swift
/// toasts.present(.normal, title: "Uploading…", group: "upload")
/// toasts.dismiss(group: "upload")
/// ```
public struct ToastGroup: RawRepresentable, Hashable, Sendable,
                          ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {

    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(stringInterpolation: DefaultStringInterpolation) {
        self.rawValue = String(stringInterpolation: stringInterpolation)
    }

    public var description: String { rawValue }
}

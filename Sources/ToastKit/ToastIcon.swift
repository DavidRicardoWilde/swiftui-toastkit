import Foundation

/// An image for a toast or one of its actions, named rather than drawn.
///
/// Foundation-only, like the rest of the model, so a toast can be built and tested
/// without a view host. The view layer turns it into an `Image`.
///
/// ```swift
/// ToastIcon.system("trash")                         // an SF Symbol
/// ToastIcon.asset("Snooze")                         // from the main bundle's asset catalog
/// ToastIcon.asset("Snooze", bundle: .module)        // from a package's resources
/// ```
public enum ToastIcon: Hashable {
    /// An SF Symbol, by name.
    case system(String)
    /// An image from an asset catalog. `nil` looks in the main bundle.
    case asset(String, bundle: Bundle? = nil)
}

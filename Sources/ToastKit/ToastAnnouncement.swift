import Foundation

/// Spoken text the stack posts for VoiceOver.
enum ToastAnnouncement {

    /// "3 notifications dismissed", pluralised by the string catalog.
    static func batchDismissed(count: Int) -> String {
        String(localized: "toast.a11y.dismissed \(count)", bundle: .module)
    }
}

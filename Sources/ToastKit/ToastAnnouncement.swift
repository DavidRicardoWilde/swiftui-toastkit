import Foundation

/// Spoken text the stack posts for VoiceOver.
enum ToastAnnouncement {

    /// "3 notifications dismissed", pluralised by the string catalog.
    static func batchDismissed(count: Int) -> String {
        String(localized: "toast.a11y.dismissed \(count)", bundle: .module)
    }

    /// "Uploading started".
    static func progressStarted(title: String) -> String {
        String(localized: "toast.a11y.progress.started \(title)", bundle: .module)
    }

    /// "Uploading, 50 percent".
    static func progressMilestone(title: String, percent: Int) -> String {
        String(localized: "toast.a11y.progress.milestone \(title) \(percent)", bundle: .module)
    }

    /// "Uploading done".
    static func progressSucceeded(title: String) -> String {
        String(localized: "toast.a11y.progress.succeeded \(title)", bundle: .module)
    }

    /// "Uploading failed".
    static func progressFailed(title: String) -> String {
        String(localized: "toast.a11y.progress.failed \(title)", bundle: .module)
    }

    /// "Uploading cancelled".
    static func progressCancelled(title: String) -> String {
        String(localized: "toast.a11y.progress.cancelled \(title)", bundle: .module)
    }
}

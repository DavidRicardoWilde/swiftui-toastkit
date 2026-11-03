import SwiftUI

/// What a ``ToastStyle`` draws a progress toast from.
///
/// ``ToastStyleConfiguration/progress`` is `nil` for an ordinary toast, and for a progress
/// toast that has finished, other than a failure that offers Retry. Lay the ready-made
/// parts out, or draw your own from the values:
///
/// ```swift
/// struct BannerToastStyle: ToastStyle {
///     static var drawsProgress: Bool { true }
///
///     func makeBody(configuration: Configuration) -> some View {
///         VStack(alignment: .leading, spacing: 6) {
///             configuration.title
///             if let progress = configuration.progress {
///                 progress.detail
///                 progress.bar
///                 progress.cancelButton
///             }
///         }
///     }
/// }
/// ```
///
/// A style that does not set ``ToastStyle/drawsProgress`` still gets a bar and a button,
/// added under whatever it draws.
public struct ToastProgressConfiguration {

    /// Where the toast is in its life.
    public let phase: ToastProgressPhase

    /// The latest progress. Unlike the payload of ``phase``, it moves with every update.
    public let value: ToastProgress

    /// The line under the title, such as "12 MB of 30 MB" or "Cancelling…". `nil` when
    /// there is nothing to say, or when the ``ToastMetrics`` hide the line.
    public let detail: Text?

    /// The fraction as a whole percent, such as "42%". `nil` while indeterminate.
    public let percent: Text?

    /// Cancel can be offered: the work is under way and a way to stop it exists. The
    /// button is dimmed and inert while the work winds down.
    public let isCancellationAvailable: Bool

    /// Retry can be offered: the work failed and it can be started again.
    public let isRetryAvailable: Bool

    let metrics: ToastMetrics
    let tint: Color
    let confirmsCancel: Bool
    let isInteractive: Bool
    /// What VoiceOver reads as the card's value, such as "42%, 12 MB of 30 MB".
    let spokenValue: String?
    let onCancel: @MainActor () -> Void
    let onRetry: @MainActor () -> Void

    init(
        phase: ToastProgressPhase,
        value: ToastProgress,
        detail: Text?,
        percent: Text?,
        isCancellationAvailable: Bool,
        isRetryAvailable: Bool,
        metrics: ToastMetrics,
        tint: Color,
        confirmsCancel: Bool,
        isInteractive: Bool,
        spokenValue: String?,
        onCancel: @escaping @MainActor () -> Void,
        onRetry: @escaping @MainActor () -> Void
    ) {
        self.phase = phase
        self.value = value
        self.detail = detail
        self.percent = percent
        self.isCancellationAvailable = isCancellationAvailable
        self.isRetryAvailable = isRetryAvailable
        self.metrics = metrics
        self.tint = tint
        self.confirmsCancel = confirmsCancel
        self.isInteractive = isInteractive
        self.spokenValue = spokenValue
        self.onCancel = onCancel
        self.onRetry = onRetry
    }

    // MARK: Parts

    /// The progress bar, indeterminate while the work winds down after a cancel.
    @MainActor
    public var bar: some View {
        ToastProgressBar(value: phase == .cancelling ? nil : value.fraction, metrics: metrics, tint: tint)
    }

    /// The Cancel button, or nothing when cancelling is not available.
    @MainActor @ViewBuilder
    public var cancelButton: some View {
        if isCancellationAvailable {
            ToastProgressButton(
                kind: .cancel,
                phase: phase,
                side: metrics.progressButtonSide,
                tint: tint,
                confirmsCancel: confirmsCancel,
                isInteractive: isInteractive,
                action: onCancel
            )
        }
    }

    /// The Retry button, or nothing when retrying is not available.
    @MainActor @ViewBuilder
    public var retryButton: some View {
        if isRetryAvailable {
            ToastProgressButton(
                kind: .retry,
                phase: phase,
                side: metrics.progressButtonSide,
                tint: tint,
                confirmsCancel: false,
                isInteractive: isInteractive,
                action: onRetry
            )
        }
    }

    // MARK: Building

    /// The configuration for a live card, or `nil` when the card draws no progress: the
    /// work has finished, or it failed and cannot be retried.
    static func make(
        toast: ToastMessage,
        cell: ToastProgressCell?,
        actions: ToastProgressActions?,
        metrics: ToastMetrics,
        tint: Color,
        locale: Locale,
        reduceMotion: Bool,
        isInteractive: Bool
    ) -> ToastProgressConfiguration? {
        guard let phase = toast.progressPhase else { return nil }
        let canRetry = cell?.canRetry ?? false
        switch phase {
        case .running, .cancelling:
            break
        case .failed:
            guard canRetry else { return nil }
        case .succeeded, .cancelled:
            return nil
        }

        var value = cell?.value ?? .indeterminate
        if cell == nil, case .running(let snapshot) = phase { value = snapshot }
        let canCancel = (cell?.canCancel ?? false) && phase.isActive && actions != nil
        let detailString = Self.detailString(
            phase: phase,
            value: value,
            metrics: metrics,
            locale: locale,
            reduceMotion: reduceMotion
        )
        return ToastProgressConfiguration(
            phase: phase,
            value: value,
            detail: detailString.map { Text(verbatim: $0) },
            percent: value.percentText(locale: locale).map { Text(verbatim: $0) },
            isCancellationAvailable: canCancel,
            isRetryAvailable: phase == .failed && canRetry && actions != nil,
            metrics: metrics,
            tint: tint,
            confirmsCancel: cell?.confirmsCancel ?? false,
            isInteractive: isInteractive,
            spokenValue: spokenValue(phase: phase, value: value, locale: locale),
            onCancel: actions?.cancel ?? {},
            onRetry: actions?.retry ?? {}
        )
    }

    /// The configuration for a departing card's stand-in: frozen where the bar stood, with
    /// no actions and no touches.
    static func frozen(
        snapshot: ToastProgress,
        toast: ToastMessage,
        metrics: ToastMetrics,
        tint: Color,
        locale: Locale = .current,
        reduceMotion: Bool = false
    ) -> ToastProgressConfiguration {
        let phase = toast.progressPhase ?? .running(snapshot)
        let detailString = Self.detailString(
            phase: phase,
            value: snapshot,
            metrics: metrics,
            locale: locale,
            reduceMotion: reduceMotion
        )
        return ToastProgressConfiguration(
            phase: phase,
            value: snapshot,
            detail: detailString.map { Text(verbatim: $0) },
            percent: snapshot.percentText(locale: locale).map { Text(verbatim: $0) },
            isCancellationAvailable: false,
            isRetryAvailable: false,
            metrics: metrics,
            tint: tint,
            confirmsCancel: false,
            isInteractive: false,
            spokenValue: nil,
            onCancel: {},
            onRetry: {}
        )
    }

    // MARK: Wording

    private static func detailString(
        phase: ToastProgressPhase,
        value: ToastProgress,
        metrics: ToastMetrics,
        locale: Locale,
        reduceMotion: Bool
    ) -> String? {
        if metrics.progressDetailLineLimit == 0 { return nil }
        switch phase {
        case .cancelling:
            return String(localized: "toast.progress.cancelling", bundle: .module, locale: locale)
        case .running:
            let text = value.detailText(locale: locale)
            // A static or absent sweep says nothing about activity, so the words do.
            if value.isIndeterminate, text == nil || reduceMotion {
                return String(localized: "toast.progress.inProgress", bundle: .module, locale: locale)
            }
            return text
        case .failed, .succeeded, .cancelled:
            return nil
        }
    }

    private static func spokenValue(phase: ToastProgressPhase, value: ToastProgress, locale: Locale) -> String? {
        switch phase {
        case .cancelling:
            return String(localized: "toast.progress.cancelling", bundle: .module, locale: locale)
        case .running:
            let parts = [value.percentText(locale: locale), value.detailText(locale: locale)].compactMap { $0 }
            if parts.isEmpty {
                return String(localized: "toast.progress.inProgress", bundle: .module, locale: locale)
            }
            return parts.joined(separator: ", ")
        case .failed, .succeeded, .cancelled:
            return nil
        }
    }
}

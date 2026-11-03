import SwiftUI

/// A thin progress bar in the kit's look: a capsule track with a capsule fill.
///
/// Determinate when `value` is a fraction, and a sweeping segment when it is `nil`. Under
/// Reduce Motion the fill follows the value without animating, and an indeterminate bar is
/// a static, half-opaque track. The bar is hidden from VoiceOver, because the card it sits
/// in carries the value.
///
/// ```swift
/// ToastProgressBar(value: 0.4)
/// ToastProgressBar(value: nil, metrics: .compact)
/// ```
///
/// Styles get one already tinted to the toast through
/// ``ToastProgressConfiguration/bar``.
public struct ToastProgressBar: View {

    private let value: Double?
    private let metrics: ToastMetrics
    private let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - value: How far along, 0...1. `nil` for work of unknown length.
    ///   - metrics: Gives the bar's height, ``ToastMetrics/progressBarHeight``.
    public init(value: Double?, metrics: ToastMetrics = .regular) {
        self.init(value: value, metrics: metrics, tint: .accentColor)
    }

    init(value: Double?, metrics: ToastMetrics, tint: Color) {
        self.value = value
        self.metrics = metrics
        self.tint = tint
    }

    public var body: some View {
        Capsule()
            .fill(tint.opacity(0.2))
            .overlay { fill }
            .clipShape(Capsule())
            .frame(height: metrics.progressBarHeight)
            .accessibilityHidden(true)
    }

    private var fraction: Double? {
        value.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil }
    }

    @ViewBuilder
    private var fill: some View {
        if let fraction {
            determinate(fraction)
        } else if reduceMotion {
            Capsule().fill(tint.opacity(0.5))
        } else {
            sweep
        }
    }

    private func determinate(_ fraction: Double) -> some View {
        let animation: Animation? = reduceMotion ? nil : .linear(duration: 0.2)
        return GeometryReader { proxy in
            Capsule()
                .fill(tint)
                .frame(width: proxy.size.width * fraction, height: proxy.size.height)
        }
        .animation(animation, value: fraction)
    }

    /// A segment about 30% of the track, crossing it once every 1.4 seconds.
    private var sweep: some View {
        TimelineView(.animation) { context in
            GeometryReader { proxy in
                let segment = proxy.size.width * 0.3
                let cycle = 1.4
                let position = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
                Capsule()
                    .fill(tint)
                    .frame(width: segment, height: proxy.size.height)
                    .offset(x: -segment + (proxy.size.width + segment) * position)
            }
        }
    }
}

// MARK: - Buttons

/// The round Cancel and Retry button a progress card carries.
///
/// It owns the "tap again" state itself, because the style that draws the button is not
/// the card, and a style has nowhere to keep state.
struct ToastProgressButton: View {

    enum Kind {
        case cancel
        case retry
    }

    let kind: Kind
    let phase: ToastProgressPhase
    /// The visual side. The tappable area grows to the platform's minimum around it.
    let side: CGFloat
    let tint: Color
    let confirmsCancel: Bool
    let isInteractive: Bool
    let action: @MainActor () -> Void

    @State private var isArmed = false

    /// How long the first tap of a confirmed cancel stays armed.
    private let armedDuration: UInt64 = 3_000_000_000

    var body: some View {
        Button(action: tap) {
            label
                .opacity(isWinding ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive || isWinding)
        .frame(minWidth: minimumTarget, minHeight: minimumTarget)
        .contentShape(Rectangle())
        #if os(iOS) || os(visionOS)
        .hoverEffect()
        #endif
        #if os(macOS)
        .help(Text(titleKey, bundle: .module))
        #endif
        // The card combines its children into one element, so the button is left out of
        // it; Cancel and Retry reach VoiceOver as the card's named actions.
        .accessibilityHidden(true)
        .task(id: isArmed) {
            guard isArmed else { return }
            try? await Task.sleep(nanoseconds: armedDuration)
            guard !Task.isCancelled else { return }
            isArmed = false
        }
    }

    /// The work is stopping, so Cancel has nothing left to do.
    private var isWinding: Bool {
        kind == .cancel && phase == .cancelling
    }

    private func tap() {
        if kind == .cancel, confirmsCancel, !isArmed {
            isArmed = true
            return
        }
        isArmed = false
        action()
    }

    @ViewBuilder
    private var label: some View {
        if isArmed {
            Text("toast.progress.confirmCancel", bundle: .module)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: side)
                .background { Capsule().fill(tint.opacity(0.18)) }
        } else {
            Image(systemName: symbolName)
                .font(.system(size: side * 0.46, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: side, height: side)
                .background { Circle().fill(tint.opacity(0.18)) }
        }
    }

    private var symbolName: String {
        switch kind {
        case .cancel: "xmark"
        case .retry: "arrow.clockwise"
        }
    }

    private var titleKey: LocalizedStringKey {
        switch kind {
        case .cancel: "toast.action.cancel"
        case .retry: "toast.progress.retry"
        }
    }

    /// The smallest tappable side each platform asks for.
    private var minimumTarget: CGFloat {
        #if os(visionOS)
        60
        #elseif os(macOS)
        28
        #else
        44
        #endif
    }
}

// MARK: - Fallback

/// The bar and button added under a style that does not draw progress itself, so a custom
/// style written before progress toasts existed still shows them.
struct ToastProgressAccessory: View {
    let configuration: ToastProgressConfiguration

    var body: some View {
        HStack(spacing: 8) {
            if configuration.phase.isActive {
                configuration.bar
            } else {
                Spacer(minLength: 0)
            }
            configuration.cancelButton
            configuration.retryButton
        }
    }
}

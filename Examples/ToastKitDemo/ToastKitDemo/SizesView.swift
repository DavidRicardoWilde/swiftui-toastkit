import SwiftUI
import ToastKit

/// Shows the three `ToastMetrics` presets side by side. Each pane owns its own
/// `ToastCenter`, because one center must never be drawn by two stacks.
@MainActor
struct SizesView: View {
    @Bindable var settings: DemoSettings

    @State private var compact = ToastCenter()
    @State private var regular = ToastCenter()
    @State private var large = ToastCenter()
    @State private var usesExplicitWidth = false
    #if os(iOS)
    @State private var typeSize = DynamicTypeSize.large
    #endif

    private var explicitWidth: ToastWidth? {
        usesExplicitWidth ? .fraction(0.9) : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                controls
                panes
            }
            .padding()
        }
        .navigationTitle("Sizes")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Show in all") { showInAll() }
                    .buttonStyle(.borderedProminent)
                Button("Dismiss all") { dismissInAll() }
                    .buttonStyle(.bordered)
            }
            Toggle("Explicit width 90 %", isOn: $usesExplicitWidth)
            #if os(iOS)
            Picker("Dynamic Type", selection: $typeSize) {
                Text("Large").tag(DynamicTypeSize.large)
                Text("XXXL").tag(DynamicTypeSize.xxxLarge)
                Text("AX1").tag(DynamicTypeSize.accessibility1)
                Text("AX3").tag(DynamicTypeSize.accessibility3)
            }
            .pickerStyle(.segmented)
            #endif
            Text(note)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var note: String {
        #if os(iOS)
        "Each preset sizes its own pane. An explicit width passed to toasts(_:width:) wins over the preset's width. Raise Dynamic Type to see the type cap each preset applies."
        #elseif os(macOS)
        "Compact is shown at 280 pt and large at 480 pt. Resize the window to see the regular preset follow the available width. An explicit width wins over the preset's width."
        #else
        "Widths are fractions of the window, so resize it to see them follow. Look at the large preset and hover a card to see its hover effect. An explicit width wins over the preset's width."
        #endif
    }

    @ViewBuilder
    private var panes: some View {
        #if os(iOS)
        HStack(alignment: .top, spacing: 8) {
            SizePane(title: "Compact", metrics: .compact, toasts: compact, width: explicitWidth, settings: settings)
            SizePane(title: "Regular", metrics: .regular, toasts: regular, width: explicitWidth, settings: settings)
            SizePane(title: "Large", metrics: .large, toasts: large, width: explicitWidth, settings: settings)
        }
        .dynamicTypeSize(typeSize)
        #elseif os(macOS)
        VStack(alignment: .leading, spacing: 16) {
            SizePane(title: "Compact · 280 pt", metrics: .compact, toasts: compact, width: explicitWidth, settings: settings)
                .frame(width: 280)
            SizePane(title: "Regular · window width", metrics: .regular, toasts: regular, width: explicitWidth, settings: settings)
            SizePane(title: "Large · 480 pt", metrics: .large, toasts: large, width: explicitWidth, settings: settings)
                .frame(width: 480)
        }
        #else
        VStack(alignment: .leading, spacing: 16) {
            SizePane(title: "Compact", metrics: .compact, toasts: compact, width: explicitWidth, settings: settings)
            SizePane(title: "Regular", metrics: .regular, toasts: regular, width: explicitWidth, settings: settings)
            SizePane(title: "Large", metrics: .large, toasts: large, width: explicitWidth, settings: settings)
        }
        #endif
    }

    private func showInAll() {
        for (name, center) in [("Compact", compact), ("Regular", regular), ("Large", large)] {
            center.present(
                .normal,
                title: "\(name) toast",
                message: "Width, padding and type follow the preset.",
                icon: .system("textformat.size"),
                duration: .seconds(6)
            )
        }
    }

    private func dismissInAll() {
        for center in [compact, regular, large] {
            center.dismissAll()
        }
    }
}

/// One preset's stage: a tinted box that hosts a single center's stack.
private struct SizePane: View {
    let title: String
    let metrics: ToastMetrics
    let toasts: ToastCenter
    let width: ToastWidth?
    let settings: DemoSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary)
                .frame(height: 220)
                .toasts(toasts, placement: settings.placement, width: width)
                .toastMetrics(metrics)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
        }
    }
}

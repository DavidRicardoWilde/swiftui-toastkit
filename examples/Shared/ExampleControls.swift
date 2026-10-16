import SwiftUI
import ToastKit

/// The controls every example shows, as form sections: what to present, which ways it
/// swipes, and where the stack sits.
struct ExampleControls: View {
    @Bindable var settings: ExampleSettings

    var body: some View {
        Section("Toast") {
            Picker("Status", selection: $settings.status) {
                ForEach(ToastMessage.Status.allCases, id: \.self) { status in
                    Text(status.title).tag(status)
                }
            }
            Toggle("Stay until dismissed", isOn: $settings.staysUntilDismissed)
            Button("Show toast") { settings.present() }
            Button("Dismiss all", role: .destructive) { settings.toasts.dismissAll() }
        }

        Section {
            Picker("Directions", selection: $settings.swipes) {
                ForEach(ExampleSwipes.allCases) { swipes in
                    Text(swipes.title).tag(swipes)
                }
            }
            Toggle("Show actions as a swipe starts", isOn: $settings.showsActionsAsSwipeStarts)
        } header: {
            Text("Swiping")
        } footer: {
            Text("Swipe a toast to run an action, or press and hold it to see them all first.")
        }

        Section("Layout") {
            Picker("Placement", selection: $settings.placement) {
                Text("Bottom").tag(ToastPlacement.bottom)
                Text("Top").tag(ToastPlacement.top)
            }
            Slider(value: $settings.widthFraction, in: 0.4...1, step: 0.1) {
                Text("Width")
            }
            LabeledContent("Width", value: "\(Int((settings.widthFraction * 100).rounded())) %")
        }

        Section("Recent actions") {
            if settings.log.isEmpty {
                Text("Tap, swipe or hold a toast.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(settings.log.enumerated()), id: \.offset) { _, entry in
                Text(entry)
            }
        }
    }
}

extension View {
    /// Presents `settings`' stack over this view the way its controls say, and logs
    /// every action chosen on it.
    func exampleToasts(_ settings: ExampleSettings) -> some View {
        toasts(settings.toasts, placement: settings.placement, width: settings.width)
            .toastSwipeHints(settings.hints)
            .onToastAction { toast, action in
                settings.record(action, on: toast)
            }
    }
}

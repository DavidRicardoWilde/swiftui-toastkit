import SwiftUI
import ToastKit

/// In a visionOS window, pinch and drag a toast to swipe it; pinch and hold to lift it
/// onto its track. There are no haptics on visionOS.
@main
struct visionOSExampleApp: App {
    @State private var settings = ExampleSettings()

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                Form {
                    ExampleControls(settings: settings)
                }
                .navigationTitle("ToastKit")
            } detail: {
                ContentUnavailableView(
                    "Toasts appear here",
                    systemImage: "rectangle.stack",
                    description: Text("Show one from the sidebar or the button below the window.")
                )
                .exampleToasts(settings)
            }
            .ornament(attachmentAnchor: .scene(.bottom)) {
                Button("Show toast", systemImage: "plus") { settings.present() }
                    .padding()
                    .glassBackgroundEffect()
            }
        }
    }
}

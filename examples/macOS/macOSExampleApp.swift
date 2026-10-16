import SwiftUI
import ToastKit

/// On the Mac, swipe a toast by clicking and dragging it; press and hold the mouse button
/// to lift it onto its track.
@main
struct macOSExampleApp: App {
    @State private var settings = ExampleSettings()

    var body: some Scene {
        WindowGroup("ToastKit") {
            NavigationSplitView {
                Form {
                    ExampleControls(settings: settings)
                }
                .formStyle(.grouped)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
            } detail: {
                ContentUnavailableView(
                    "Toasts appear here",
                    systemImage: "rectangle.stack",
                    description: Text("Show one from the sidebar, then click and drag it, or hold it down.")
                )
                .exampleToasts(settings)
            }
        }
        .defaultSize(width: 960, height: 640)
    }
}

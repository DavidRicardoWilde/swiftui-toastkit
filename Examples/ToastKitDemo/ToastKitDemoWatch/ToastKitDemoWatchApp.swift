import SwiftUI

/// A standalone watch app: no iPhone companion is needed to install or run it.
@main
struct ToastKitDemoWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

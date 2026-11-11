import SwiftUI

@main
struct RestTimerApp: App {
    init() {
        WatchConnectivityBridge.shared.Activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

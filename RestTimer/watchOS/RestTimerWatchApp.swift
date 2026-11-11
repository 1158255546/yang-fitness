import SwiftUI

@main
struct RestTimerWatchApp: App {
    @StateObject private var runtimeSession: WatchRuntimeSessionCoordinator
    @StateObject private var countdown: RestCountdownController

    init() {
        let runtime = WatchRuntimeSessionCoordinator()
        _runtimeSession = StateObject(wrappedValue: runtime)
        _countdown = StateObject(wrappedValue: RestCountdownController(runtimeSession: runtime))
        WatchConnectivityBridge.shared.Activate()
    }

    var body: some Scene {
        WindowGroup {
            RestCountdownView(controller: countdown, runtimeSession: runtimeSession)
                .onAppear {
                    WatchConnectivityBridge.shared.onReceiveCommand = { message in
                        countdown.Handle(message)
                    }
                }
        }
    }
}

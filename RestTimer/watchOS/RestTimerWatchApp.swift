import SwiftUI

@main
struct RestTimerWatchApp: App {
    @StateObject private var countdown = RestCountdownController()

    init() {
        WatchConnectivityBridge.shared.Activate()
    }

    var body: some Scene {
        WindowGroup {
            RestCountdownView(controller: countdown)
                .onAppear {
                    WatchConnectivityBridge.shared.onReceiveMessage = { message in
                        countdown.Handle(message)
                    }
                    // TODO: 启动 HKWorkoutSession 或 WKExtendedRuntimeSession，保证锁屏/后台准时
                }
        }
    }
}

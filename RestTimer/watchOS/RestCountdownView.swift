import SwiftUI
import WatchKit

/// Watch 本地倒计时控制器：事实源在此，结束时播放强触觉。
@MainActor
final class RestCountdownController: ObservableObject {
    @Published private(set) var state = RestCountdownState()

    private var timer: Timer?
    private var deadline: Date?

    func Handle(_ message: RestSessionMessage) {
        switch message.command {
        case .start:
            Start(durationSeconds: message.durationSeconds, setIndex: message.setIndex)
        case .cancel:
            Cancel(playHaptic: false)
        }
    }

    func Start(durationSeconds: Int, setIndex: Int?) {
        Cancel(playHaptic: false)
        guard durationSeconds > 0 else { return }
        deadline = Date().addingTimeInterval(TimeInterval(durationSeconds))
        state = RestCountdownState(
            remainingSeconds: durationSeconds,
            isRunning: true,
            setIndex: setIndex
        )
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.Tick()
            }
        }
    }

    func Cancel(playHaptic: Bool) {
        timer?.invalidate()
        timer = nil
        deadline = nil
        if playHaptic {
            PlayCompletionHaptic()
        }
        state = RestCountdownState(
            remainingSeconds: 0,
            isRunning: false,
            setIndex: state.setIndex
        )
    }

    private func Tick() {
        guard let deadline else { return }
        let remaining = Int(ceil(deadline.timeIntervalSinceNow))
        if remaining <= 0 {
            timer?.invalidate()
            timer = nil
            self.deadline = nil
            state.remainingSeconds = 0
            state.isRunning = false
            PlayCompletionHaptic()
            // TODO: 可选：经 WCSession 回传「已完成」状态给 iPhone（非到点主路径）
            return
        }
        state.remainingSeconds = remaining
    }

    /// 强触觉 stub；真机可换成更明显的 `.notification` / 自定义 haptic。
    func PlayCompletionHaptic() {
        WKInterfaceDevice.current().play(.notification)
        // TODO: 若需更强反馈，评估多次 play 或 CHHapticPattern（注意系统限制）
    }
}

struct RestCountdownView: View {
    @ObservedObject var controller: RestCountdownController

    var body: some View {
        VStack(spacing: 8) {
            if let setIndex = controller.state.setIndex {
                Text("组 \(setIndex)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(timeLabel)
                .font(.system(.title, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.5)

            if controller.state.isRunning {
                Button("提前结束") {
                    controller.Cancel(playHaptic: false)
                }
                .tint(.red)
            } else {
                Text("等待 iPhone 开始")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var timeLabel: String {
        let s = max(0, controller.state.remainingSeconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}

#Preview {
    RestCountdownView(controller: RestCountdownController())
}

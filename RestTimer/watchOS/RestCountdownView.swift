import SwiftUI
import WatchKit

/// Watch 本地倒计时控制器：事实源在此；到点强触觉；取消不触发到点触觉。
@MainActor
final class RestCountdownController: ObservableObject {
    @Published private(set) var state = RestCountdownState()

    private var timer: Timer?
    private var deadline: Date?
    private let runtimeSession: WatchRuntimeSessionCoordinator
    /// 可选状态回传；默认走 shared bridge。
    var reportStatus: ((RestStatusReport) -> Void)?

    init(runtimeSession: WatchRuntimeSessionCoordinator = WatchRuntimeSessionCoordinator()) {
        self.runtimeSession = runtimeSession
        self.reportStatus = { report in
            WatchConnectivityBridge.shared.SendStatus(report)
        }
    }

    func Handle(_ message: RestSessionMessage) {
        switch message.command {
        case .start:
            Start(durationSeconds: message.durationSeconds, setIndex: message.setIndex)
        case .cancel:
            Cancel(playHaptic: false)
        }
    }

    func Start(durationSeconds: Int, setIndex: Int?) {
        Cancel(playHaptic: false, report: false)
        guard durationSeconds > 0 else {
            state = RestCountdownState(phase: .idle, setIndex: setIndex)
            PublishStatus()
            return
        }
        deadline = Date().addingTimeInterval(TimeInterval(durationSeconds))
        state = RestCountdownState(
            remainingSeconds: durationSeconds,
            durationSeconds: durationSeconds,
            isRunning: true,
            phase: .running,
            setIndex: setIndex
        )
        runtimeSession.StartForRest()
        // 0.25s 刷新 UI；结束时刻以 deadline 为准，不累计漂移。
        let tick = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.Tick()
            }
        }
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
        PublishStatus()
    }

    /// 取消 / 提前结束：停止计时且默认不播放到点触觉。
    func Cancel(playHaptic: Bool, report: Bool = true) {
        let hadDeadline = deadline != nil || state.isRunning
        timer?.invalidate()
        timer = nil
        deadline = nil
        if hadDeadline {
            runtimeSession.Stop()
        }
        // 取消路径默认不播放到点触觉（仅 playHaptic == true 时例外）。
        if playHaptic {
            PlayCompletionHaptic()
        }
        let previousSet = state.setIndex
        let previousDuration = state.durationSeconds
        state = RestCountdownState(
            remainingSeconds: 0,
            durationSeconds: previousDuration,
            isRunning: false,
            phase: .cancelled,
            setIndex: previousSet
        )
        if report {
            PublishStatus()
        }
    }

    private func Tick() {
        guard let deadline else { return }
        let remaining = Int(ceil(deadline.timeIntervalSinceNow))
        if remaining <= 0 {
            Complete()
            return
        }
        if state.remainingSeconds != remaining {
            state.remainingSeconds = remaining
            // 节流：整秒变化时再镜像，避免刷屏。
            PublishStatus()
        }
    }

    private func Complete() {
        timer?.invalidate()
        timer = nil
        deadline = nil
        runtimeSession.Stop()
        state.remainingSeconds = 0
        state.isRunning = false
        state.phase = .completed
        PlayCompletionHaptic()
        PublishStatus()
    }

    private func PublishStatus() {
        reportStatus?(state.AsStatusReport())
    }

    /// 强触觉：连续 notification，提升组间休息结束的可感知度。
    func PlayCompletionHaptic() {
        let device = WKInterfaceDevice.current()
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            device.play(.notification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
            device.play(.directionUp)
        }
        // TODO(Mac/device): 若需更强自定义反馈，评估 CHHapticPattern（注意系统限制）
    }
}

struct RestCountdownView: View {
    @ObservedObject var controller: RestCountdownController
    @ObservedObject var runtimeSession: WatchRuntimeSessionCoordinator

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
                .accessibilityLabel("剩余 \(controller.state.remainingSeconds) 秒")

            if controller.state.isRunning {
                Button("提前结束") {
                    controller.Cancel(playHaptic: false)
                }
                .tint(.red)
            } else {
                Text(idleLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(runtimeSession.lastSessionNote)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding()
    }

    private var timeLabel: String {
        let s = max(0, controller.state.remainingSeconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    private var idleLabel: String {
        switch controller.state.phase {
        case .completed:
            return "休息结束"
        case .cancelled:
            return "已取消"
        case .idle, .running:
            return "等待 iPhone 开始"
        }
    }
}

#Preview {
    let runtime = WatchRuntimeSessionCoordinator()
    RestCountdownView(
        controller: RestCountdownController(runtimeSession: runtime),
        runtimeSession: runtime
    )
}

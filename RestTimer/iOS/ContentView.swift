import SwiftUI

/// iPhone：60/90/120 预设 + 开始/取消；到点触觉由 Watch 本地负责。
struct ContentView: View {
    @State private var selectedDuration: Int = 90
    @State private var setIndex: Int = 1
    @State private var localStatusText: String = "就绪"
    @ObservedObject private var bridge = WatchConnectivityBridge.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("组 \(setIndex)")
                    .font(.title2)

                Picker("休息时长", selection: $selectedDuration) {
                    ForEach(RestSessionMessage.presets, id: \.self) { seconds in
                        Text("\(seconds) 秒").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("开始休息") {
                        StartRest()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("取消休息", role: .destructive) {
                        CancelRest()
                    }
                    .buttonStyle(.bordered)
                }

                connectivityBanner

                VStack(alignment: .leading, spacing: 6) {
                    Text(localStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let mirrored = bridge.mirroredStatus {
                        Text(MirroredLabel(mirrored))
                            .font(.footnote)
                            .foregroundStyle(.primary)
                    }
                    if let note = bridge.lastDeliveryNote {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                if let err = bridge.lastErrorDescription {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Rest Timer")
        }
    }

    @ViewBuilder
    private var connectivityBanner: some View {
        let activated = bridge.isSessionActivated
        let reachable = bridge.isCounterpartReachable
        Group {
            if !activated {
                Label(
                    "正在激活与 Watch 的连接…（激活前发送可能失败）",
                    systemImage: "antenna.radiowaves.left.and.right"
                )
                .foregroundStyle(.orange)
            } else if !reachable {
                Label(
                    "Watch 暂不可达：命令将排队，上线后送达。到点触觉仍由 Watch 本地 deadline 触发。",
                    systemImage: "applewatch.slash"
                )
                .foregroundStyle(.orange)
            } else {
                Label("Watch 已连接", systemImage: "applewatch")
                    .foregroundStyle(.green)
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func StartRest() {
        let message = RestSessionMessage.Start(
            durationSeconds: selectedDuration,
            setIndex: setIndex
        )
        bridge.ClearError()
        bridge.Send(message)
        localStatusText = "已发送开始 \(selectedDuration)s（组 \(setIndex)）"
    }

    private func CancelRest() {
        let message = RestSessionMessage.Cancel(setIndex: setIndex)
        bridge.ClearError()
        bridge.Send(message)
        localStatusText = "已发送取消"
    }

    private func MirroredLabel(_ report: RestStatusReport) -> String {
        let setPart: String
        if let idx = report.setIndex {
            setPart = "组 \(idx) · "
        } else {
            setPart = ""
        }
        switch report.phase {
        case .idle:
            return "Watch：\(setPart)空闲"
        case .running:
            return "Watch：\(setPart)剩余 \(report.remainingSeconds)s"
        case .completed:
            return "Watch：\(setPart)已完成"
        case .cancelled:
            return "Watch：\(setPart)已取消"
        }
    }
}

#Preview {
    ContentView()
}

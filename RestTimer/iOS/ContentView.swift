import SwiftUI

/// iPhone：预设休息 + 取消。到点触觉由 Watch 本地负责，本页不发「time’s up」。
struct ContentView: View {
    @State private var selectedDuration: Int = 90
    @State private var setIndex: Int = 1
    @State private var statusText: String = "就绪"
    @ObservedObject private var bridge = WatchConnectivityBridge.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("组 \(setIndex)")
                    .font(.title2)

                Picker("休息时长", selection: $selectedDuration) {
                    ForEach(RestSessionMessage.presets, id: \.self) { seconds in
                        Text("\(seconds) 秒").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Button("开始休息") {
                    StartRest()
                }
                .buttonStyle(.borderedProminent)

                Button("取消休息", role: .destructive) {
                    CancelRest()
                }
                .buttonStyle(.bordered)

                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

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

    private func StartRest() {
        let message = RestSessionMessage.Start(
            durationSeconds: selectedDuration,
            setIndex: setIndex
        )
        bridge.Send(message)
        statusText = "已发送开始 \(selectedDuration)s（组 \(setIndex)）"
        // TODO: 收到 Watch 状态回传后再推进 setIndex / UI
    }

    private func CancelRest() {
        let message = RestSessionMessage.Cancel(setIndex: setIndex)
        bridge.Send(message)
        statusText = "已发送取消"
    }
}

#Preview {
    ContentView()
}

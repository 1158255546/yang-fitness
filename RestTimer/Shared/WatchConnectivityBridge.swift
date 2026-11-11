import Foundation
import WatchConnectivity

/// 最近一次命令投递方式，供 iPhone UI 展示。
public enum RestDeliveryMode: String, Sendable, Equatable {
    case sendMessage
    case transferUserInfo
    case failed
    case notAttempted
}

/// WCSession 应用层桥：编码/解码 RestCommand 与状态镜像；不可达时降级并暴露清晰 UI 状态。
@MainActor
public final class WatchConnectivityBridge: NSObject, ObservableObject {
    public static let shared = WatchConnectivityBridge()

    @Published public private(set) var lastErrorDescription: String?
    @Published public private(set) var isSessionActivated: Bool = false
    @Published public private(set) var isCounterpartReachable: Bool = false
    @Published public private(set) var lastDeliveryMode: RestDeliveryMode = .notAttempted
    @Published public private(set) var lastDeliveryNote: String?
    /// Watch 回传的镜像状态（可选）。
    @Published public private(set) var mirroredStatus: RestStatusReport?

    /// Watch / Phone 侧注入：收到 start/cancel 后由计时器或 UI 消费。
    public var onReceiveCommand: ((RestSessionMessage) -> Void)?
    /// iPhone 侧注入：收到 Watch 状态镜像。
    public var onReceiveStatus: ((RestStatusReport) -> Void)?

    /// 兼容旧骨架命名。
    public var onReceiveMessage: ((RestSessionMessage) -> Void)? {
        get { onReceiveCommand }
        set { onReceiveCommand = newValue }
    }

    private override init() {
        super.init()
    }

    public func Activate() {
        guard WCSession.isSupported() else {
            lastErrorDescription = "WCSession 在此设备上不受支持"
            isSessionActivated = false
            isCounterpartReachable = false
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        RefreshReachability(from: session)
    }

    /// 发送 start/cancel。可达优先 `sendMessage`；失败或不可达则 `transferUserInfo`。
    public func Send(_ message: RestSessionMessage) {
        guard WCSession.isSupported() else {
            lastErrorDescription = "WCSession 不受支持，无法发送"
            lastDeliveryMode = .failed
            lastDeliveryNote = "设备不支持 WatchConnectivity"
            return
        }
        let session = WCSession.default
        guard isSessionActivated || session.activationState == .activated else {
            lastErrorDescription = "WCSession 尚未激活，请稍候再试"
            lastDeliveryMode = .failed
            lastDeliveryNote = "会话未激活"
            return
        }

        let payload: [String: Any]
        do {
            payload = try message.EncodeForWatchConnectivity()
        } catch {
            lastErrorDescription = "编码 RestCommand 失败: \(error.localizedDescription)"
            lastDeliveryMode = .failed
            lastDeliveryNote = "编码失败"
            return
        }

        RefreshReachability(from: session)

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    self.lastErrorDescription =
                        "即时发送失败，已改排队投递: \(error.localizedDescription)"
                    self.EnqueueTransfer(payload, session: session, reason: "sendMessage 失败回退")
                }
            }
            lastErrorDescription = nil
            lastDeliveryMode = .sendMessage
            lastDeliveryNote = "Watch 可达，已即时发送"
        } else {
            EnqueueTransfer(payload, session: session, reason: "Watch 当前不可达")
        }
    }

    /// Watch → iPhone 状态镜像（可选）。不可达时同样排队。
    public func SendStatus(_ report: RestStatusReport) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        let payload: [String: Any]
        do {
            payload = try report.EncodeForWatchConnectivity()
        } catch {
            lastErrorDescription = "编码状态失败: \(error.localizedDescription)"
            return
        }
        RefreshReachability(from: session)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.EnqueueTransfer(
                        payload,
                        session: WCSession.default,
                        reason: "状态 sendMessage 失败: \(error.localizedDescription)"
                    )
                }
            }
        } else {
            EnqueueTransfer(payload, session: session, reason: "状态排队（Watch/Phone 暂不可达）")
        }
    }

    public func ClearError() {
        lastErrorDescription = nil
    }

    private func EnqueueTransfer(
        _ payload: [String: Any],
        session: WCSession,
        reason: String
    ) {
        session.transferUserInfo(payload)
        lastDeliveryMode = .transferUserInfo
        lastDeliveryNote = "\(reason)；已用 transferUserInfo 排队，Watch 上线后送达"
        if lastErrorDescription == nil {
            lastErrorDescription = lastDeliveryNote
        }
    }

    private func RefreshReachability(from session: WCSession) {
        isSessionActivated = (session.activationState == .activated)
        isCounterpartReachable = session.isReachable
    }

    private func HandleIncoming(_ userInfo: [String: Any]) {
        do {
            switch try RestWirePayload.Decode(userInfo) {
            case .command(let message):
                onReceiveCommand?(message)
            case .status(let report):
                mirroredStatus = report
                onReceiveStatus?(report)
            }
        } catch {
            lastErrorDescription = "解码失败: \(error.localizedDescription)"
        }
    }
}

extension WatchConnectivityBridge: WCSessionDelegate {
    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isSessionActivated = (activationState == .activated)
            self.isCounterpartReachable = session.isReachable
            if let error {
                self.lastErrorDescription = "激活失败: \(error.localizedDescription)"
            } else if activationState != .activated {
                self.lastErrorDescription = "WCSession 激活状态: \(activationState.rawValue)"
            }
        }
    }

#if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isCounterpartReachable = session.isReachable
            if !session.isReachable {
                self.lastDeliveryNote = "对端暂时不可达；新命令将排队投递"
            } else {
                self.lastDeliveryNote = "对端已可达"
                if self.lastDeliveryMode == .transferUserInfo {
                    self.lastErrorDescription = nil
                }
            }
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.HandleIncoming(message)
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            self.HandleIncoming(userInfo)
        }
    }
}

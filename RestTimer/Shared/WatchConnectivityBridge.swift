import Foundation
import WatchConnectivity

/// WCSession 薄封装。iPhone 发 start/cancel；Watch 收命令并可选回传状态。
/// TODO: 在真机上处理 `activationDidComplete`、可达性变化、以及 `transferUserInfo` 后备路径。
@MainActor
public final class WatchConnectivityBridge: NSObject, ObservableObject {
    public static let shared = WatchConnectivityBridge()

    @Published public private(set) var lastErrorDescription: String?
    @Published public private(set) var isSessionActivated: Bool = false

    /// Watch 侧注入：收到消息后由 UI / 计时器消费。
    public var onReceiveMessage: ((RestSessionMessage) -> Void)?

    private override init() {
        super.init()
    }

    public func Activate() {
        guard WCSession.isSupported() else {
            lastErrorDescription = "WCSession 在此设备上不受支持"
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// 发送应用层命令。优先 `sendMessage`；失败时可改用 `transferUserInfo`（TODO）。
    public func Send(_ message: RestSessionMessage) {
        guard WCSession.isSupported() else {
            lastErrorDescription = "WCSession 不受支持，无法发送"
            return
        }
        let session = WCSession.default
        do {
            let data = try JSONEncoder().encode(message)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                lastErrorDescription = "消息编码结果不是字典"
                return
            }
            if session.isReachable {
                session.sendMessage(json, replyHandler: nil) { [weak self] error in
                    Task { @MainActor in
                        self?.lastErrorDescription = error.localizedDescription
                        // TODO: 不可达时回退 transferUserInfo(json)
                    }
                }
            } else {
                session.transferUserInfo(json)
                // TODO: 记录排队中的 transfer，便于调试
            }
        } catch {
            lastErrorDescription = "编码 RestSessionMessage 失败: \(error.localizedDescription)"
        }
    }

    private func DecodeMessage(_ userInfo: [String: Any]) -> RestSessionMessage? {
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo)
            return try JSONDecoder().decode(RestSessionMessage.self, from: data)
        } catch {
            lastErrorDescription = "解码失败: \(error.localizedDescription)"
            return nil
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
            if let error {
                self.lastErrorDescription = error.localizedDescription
            }
        }
    }

#if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        // iOS：配对切换后需重新 activate
        session.activate()
    }
#endif

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            if let parsed = self.DecodeMessage(message) {
                self.onReceiveMessage?(parsed)
            }
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            if let parsed = self.DecodeMessage(userInfo) {
                self.onReceiveMessage?(parsed)
            }
        }
    }
}

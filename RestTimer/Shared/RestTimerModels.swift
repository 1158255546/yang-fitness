import Foundation

/// 组间休息命令：由 iPhone 编排，Watch 作为倒计时事实源执行。
public enum RestCommand: String, Codable, Sendable {
    case start
    case cancel
}

/// 通过 WCSession 传递的应用层载荷。
public struct RestSessionMessage: Codable, Sendable, Equatable {
    public var command: RestCommand
    /// 休息时长（秒）。cancel 时可忽略。
    public var durationSeconds: Int
    /// 可选：当前组序号，便于 UI 展示。
    public var setIndex: Int?

    public init(
        command: RestCommand,
        durationSeconds: Int,
        setIndex: Int? = nil
    ) {
        self.command = command
        self.durationSeconds = durationSeconds
        self.setIndex = setIndex
    }

    public static let presets: [Int] = [60, 90, 120]

    public static func Start(
        durationSeconds: Int,
        setIndex: Int? = nil
    ) -> RestSessionMessage {
        RestSessionMessage(
            command: .start,
            durationSeconds: durationSeconds,
            setIndex: setIndex
        )
    }

    public static func Cancel(setIndex: Int? = nil) -> RestSessionMessage {
        RestSessionMessage(
            command: .cancel,
            durationSeconds: 0,
            setIndex: setIndex
        )
    }
}

/// Watch 本地倒计时状态（不依赖 iPhone 到点消息）。
public struct RestCountdownState: Sendable, Equatable {
    public var remainingSeconds: Int
    public var isRunning: Bool
    public var setIndex: Int?

    public init(
        remainingSeconds: Int = 0,
        isRunning: Bool = false,
        setIndex: Int? = nil
    ) {
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.setIndex = setIndex
    }
}

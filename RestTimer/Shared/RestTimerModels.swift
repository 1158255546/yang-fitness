import Foundation

/// 组间休息命令：由 iPhone 编排，Watch 作为倒计时事实源执行。
public enum RestCommand: String, Codable, Sendable, Equatable {
    case start
    case cancel
}

/// Watch 回传给 iPhone 的阶段（可选镜像；到点主路径仍在 Watch 本地）。
public enum RestPhase: String, Codable, Sendable, Equatable {
    case idle
    case running
    case completed
    case cancelled
}

/// 通过 WCSession 传递的应用层命令载荷。
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

    /// 编码为 WCSession 可用的属性列表字典（省略 nil，避免 NSNull）。
    public func EncodeForWatchConnectivity() throws -> [String: Any] {
        var payload: [String: Any] = [
            "kind": "command",
            "command": command.rawValue,
            "durationSeconds": durationSeconds,
        ]
        if let setIndex {
            payload["setIndex"] = setIndex
        }
        return payload
    }

    /// 从 WCSession 字典解码；非法字段抛出明确错误。
    public static func DecodeFromWatchConnectivity(
        _ userInfo: [String: Any]
    ) throws -> RestSessionMessage {
        guard let commandRaw = userInfo["command"] as? String else {
            throw RestMessageCodecError.MissingField("command")
        }
        guard let command = RestCommand(rawValue: commandRaw) else {
            throw RestMessageCodecError.InvalidCommand(commandRaw)
        }
        let duration: Int
        if let intValue = userInfo["durationSeconds"] as? Int {
            duration = intValue
        } else if let number = userInfo["durationSeconds"] as? NSNumber {
            duration = number.intValue
        } else if command == .cancel {
            duration = 0
        } else {
            throw RestMessageCodecError.MissingField("durationSeconds")
        }
        let setIndex = Self.OptionalInt(from: userInfo["setIndex"])
        return RestSessionMessage(
            command: command,
            durationSeconds: duration,
            setIndex: setIndex
        )
    }

    private static func OptionalInt(from value: Any?) -> Int? {
        if value == nil || value is NSNull { return nil }
        if let intValue = value as? Int { return intValue }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}

/// Watch → iPhone 状态镜像（非到点主路径）。
public struct RestStatusReport: Codable, Sendable, Equatable {
    public var phase: RestPhase
    public var remainingSeconds: Int
    public var durationSeconds: Int
    public var setIndex: Int?

    public init(
        phase: RestPhase,
        remainingSeconds: Int,
        durationSeconds: Int = 0,
        setIndex: Int? = nil
    ) {
        self.phase = phase
        self.remainingSeconds = remainingSeconds
        self.durationSeconds = durationSeconds
        self.setIndex = setIndex
    }

    public func EncodeForWatchConnectivity() throws -> [String: Any] {
        var payload: [String: Any] = [
            "kind": "status",
            "phase": phase.rawValue,
            "remainingSeconds": remainingSeconds,
            "durationSeconds": durationSeconds,
        ]
        if let setIndex {
            payload["setIndex"] = setIndex
        }
        return payload
    }

    public static func DecodeFromWatchConnectivity(
        _ userInfo: [String: Any]
    ) throws -> RestStatusReport {
        guard let phaseRaw = userInfo["phase"] as? String else {
            throw RestMessageCodecError.MissingField("phase")
        }
        guard let phase = RestPhase(rawValue: phaseRaw) else {
            throw RestMessageCodecError.InvalidPhase(phaseRaw)
        }
        let remaining = IntFromPlist(userInfo["remainingSeconds"]) ?? 0
        let duration = IntFromPlist(userInfo["durationSeconds"]) ?? 0
        let setIndex: Int?
        if let value = userInfo["setIndex"], !(value is NSNull) {
            setIndex = IntFromPlist(value)
        } else {
            setIndex = nil
        }
        return RestStatusReport(
            phase: phase,
            remainingSeconds: remaining,
            durationSeconds: duration,
            setIndex: setIndex
        )
    }

    private static func IntFromPlist(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}

/// Watch 本地倒计时状态（不依赖 iPhone 到点消息）。
public struct RestCountdownState: Sendable, Equatable {
    public var remainingSeconds: Int
    public var durationSeconds: Int
    public var isRunning: Bool
    public var phase: RestPhase
    public var setIndex: Int?

    public init(
        remainingSeconds: Int = 0,
        durationSeconds: Int = 0,
        isRunning: Bool = false,
        phase: RestPhase = .idle,
        setIndex: Int? = nil
    ) {
        self.remainingSeconds = remainingSeconds
        self.durationSeconds = durationSeconds
        self.isRunning = isRunning
        self.phase = phase
        self.setIndex = setIndex
    }

    public func AsStatusReport() -> RestStatusReport {
        RestStatusReport(
            phase: phase,
            remainingSeconds: remainingSeconds,
            durationSeconds: durationSeconds,
            setIndex: setIndex
        )
    }
}

public enum RestMessageCodecError: Error, LocalizedError, Sendable {
    case MissingField(String)
    case InvalidCommand(String)
    case InvalidPhase(String)
    case UnknownKind(String)

    public var errorDescription: String? {
        switch self {
        case .MissingField(let name):
            return "缺少字段: \(name)"
        case .InvalidCommand(let raw):
            return "未知 RestCommand: \(raw)"
        case .InvalidPhase(let raw):
            return "未知 RestPhase: \(raw)"
        case .UnknownKind(let raw):
            return "未知消息 kind: \(raw)"
        }
    }
}

/// 解析 WCSession 字典：命令或状态。
public enum RestWirePayload: Sendable, Equatable {
    case command(RestSessionMessage)
    case status(RestStatusReport)

    public static func Decode(_ userInfo: [String: Any]) throws -> RestWirePayload {
        let kind = (userInfo["kind"] as? String) ?? InferKind(userInfo)
        switch kind {
        case "command":
            return .command(try RestSessionMessage.DecodeFromWatchConnectivity(userInfo))
        case "status":
            return .status(try RestStatusReport.DecodeFromWatchConnectivity(userInfo))
        default:
            throw RestMessageCodecError.UnknownKind(kind)
        }
    }

    /// 兼容骨架期无 `kind` 字段的旧消息。
    private static func InferKind(_ userInfo: [String: Any]) -> String {
        if userInfo["command"] is String { return "command" }
        if userInfo["phase"] is String { return "status" }
        return "unknown"
    }
}

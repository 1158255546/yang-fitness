import Foundation

#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

/// 锁屏 / 垂腕准时依赖的后台会话钩子（MVP stub）。
///
/// **Mac / 真机 TODO：**
/// 1. 在 Xcode 为 Watch target 打开 HealthKit 或 Extended Runtime 相关 capability。
/// 2. 优先尝试 `HKWorkoutSession`（真实训练上下文）；否则 `WKExtendedRuntimeSession`。
/// 3. 在休息开始时 Start，在取消/完成后 Stop；处理系统中断回调。
/// 4. 本文件在 Linux/Windows 上仅作结构占位，不硬依赖可链接的会话类型。
@MainActor
public final class WatchRuntimeSessionCoordinator: NSObject, ObservableObject {
    public enum Backend: String, Sendable {
        case none
        case healthKitWorkout
        case extendedRuntime
    }

    @Published public private(set) var activeBackend: Backend = .none
    @Published public private(set) var lastSessionNote: String =
        "会话未启动（stub；请在 Mac 真机接入 HKWorkoutSession / WKExtendedRuntimeSession）"

#if canImport(HealthKit)
    // TODO(Mac): 持有 HKWorkoutSession / HKWorkoutBuilder，并实现 HKWorkoutSessionDelegate。
    private var workoutSession: HKWorkoutSession?
#endif

#if os(watchOS)
    // TODO(Mac): 持有 WKExtendedRuntimeSession，并实现 WKExtendedRuntimeSessionDelegate。
    private var extendedSession: WKExtendedRuntimeSession?
#endif

    public func StartForRest() {
        // 不在此硬依赖 HealthKit / Extended Runtime，避免无 entitlement 时无法编译结构。
        // 真机接入时按优先级尝试：
        // 1) TryStartHealthKitWorkout()
        // 2) TryStartExtendedRuntime()
        activeBackend = .none
        lastSessionNote =
            "TODO(Mac/device): 启动 HKWorkoutSession 或 WKExtendedRuntimeSession 以保证锁屏/后台准时"
    }

    public func Stop() {
#if canImport(HealthKit)
        workoutSession = nil
#endif
#if os(watchOS)
        extendedSession?.invalidate()
        extendedSession = nil
#endif
        activeBackend = .none
        lastSessionNote = "会话已停止（stub）"
    }

    // MARK: - Mac / device hooks（保留方法签名，便于真机补齐）

    /// TODO(Mac): 创建 HKWorkoutSession(activityType: .traditionalStrengthTraining, …) 并 start。
    public func TryStartHealthKitWorkout() {
        lastSessionNote =
            "TODO(Mac): 实现 HKWorkoutSession；需 HealthKit entitlement 与 Info.plist 用途说明"
        // activeBackend = .healthKitWorkout
    }

    /// TODO(Mac): 创建 WKExtendedRuntimeSession，选符合审核的 session type 并 start。
    public func TryStartExtendedRuntime() {
        lastSessionNote =
            "TODO(Mac): 实现 WKExtendedRuntimeSession；注意系统用途与时长上限"
        // activeBackend = .extendedRuntime
    }
}

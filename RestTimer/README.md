# RestTimer（iOS + watchOS）

本目录是 **yang's Fitness** 仓库中的源码骨架，便于在 Mac / Xcode 中打开并做真机验证。

配套文档（仓库根）：

- 可行性：[`docs/watch-rest-timer-feasibility.md`](../docs/watch-rest-timer-feasibility.md)
- 验收：[`docs/mvp-acceptance.md`](../docs/mvp-acceptance.md)

## 目录

```
RestTimer/
  README.md
  Shared/
    RestTimerModels.swift          # start/cancel、时长、组序号
    WatchConnectivityBridge.swift  # WCSession 封装（含 TODO）
  iOS/
    RestTimerApp.swift
    ContentView.swift              # 60/90/120 预设 + 取消
  watchOS/
    RestTimerWatchApp.swift
    RestCountdownView.swift        # 本地 Timer + 到点触觉 stub
```

本 PR **未**提交完整 `.xcodeproj`（Linux/Cloud Agent 无 Xcode，无法可靠产出）。推荐用 Xcode 新建工程后把上述 Swift 文件加进去；或在 Mac 上对仓库根 `project.yml` 运行 `xcodegen generate`。

## 在 Mac / Xcode 中搭建（推荐路径）

1. 打开 Xcode → **File → New → Project** → **iOS App**（SwiftUI，Swift）。
2. 工程名例如 `RestTimer`；Bundle ID 自定。
3. **File → New → Target** → **watchOS → App**，嵌入到 iOS App（勾选 Embed）。
4. 将 `Shared/*.swift` 勾进 **iOS 与 watchOS 两个 target** 的 Target Membership。
5. 将 `iOS/*.swift` 仅加入 iOS target；删除 Xcode 模板自带的重复 `@main` / ContentView（避免双入口冲突）。
6. 将 `watchOS/*.swift` 仅加入 Watch target；同样去掉模板重复入口。
7. 两个 App target 的 **Signing & Capabilities**：
   - 选你的 Team（个人开发者账号即可，自用真机）。
   - iOS + Watch：**Background Modes** 按会话方案勾选（见下）。
   - 若用 `HKWorkoutSession`：加 **HealthKit**，并在 Info.plist 写用途说明。
8. 真机：iPhone 与配对的 Apple Watch 均信任此开发者证书后 Run（Watch scheme 选真机 Watch）。

### Capability / Info.plist 要点

| 方案 | 建议 |
|------|------|
| `HKWorkoutSession`（优先） | HealthKit entitlement；Info.plist：`NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`；Workout 会话在休息或整次训练期间保持活跃 |
| `WKExtendedRuntimeSession` | 用途须符合系统允许的 session type；有时长上限；适合先验证准时性 |
| WatchConnectivity | 无需单独 capability；双端均 `Activate()` |
| **不要**把 iPhone 本地通知镜像当作到点主路径 | 到点触觉必须在 Watch 本地 `deadline` 触发 |

## 设计锚点（实现时勿偏离）

- Watch = 倒计时事实源；iPhone 只发 start/cancel/duration。
- 结束强触觉在 `RestCountdownController.PlayCompletionHaptic()`。
- 锁屏 / 后台准时依赖 Workout 或 Extended Runtime（文件中有 TODO，需在真机补齐会话生命周期）。

## 真机验收

按仓库文档执行：[`docs/mvp-acceptance.md`](../docs/mvp-acceptance.md)（锁屏、垂腕、取消、DND 已知限制）。模拟器无法替代佩戴触觉验收。

## 下一步

1. 在 Watch 侧实现会话（HKWorkout 或 Extended Runtime）。
2. 按验收矩阵在真机打勾，再考虑非 MVP 功能。

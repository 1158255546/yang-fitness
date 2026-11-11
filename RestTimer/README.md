# RestTimer（iOS + watchOS）MVP

本目录是 **yang's Fitness** 的 RestTimer 源码。可在 **Windows** 编辑；在 **Mac + Xcode** 生成工程并真机验收。

配套文档（仓库根）：

- 可行性：[`docs/watch-rest-timer-feasibility.md`](../docs/watch-rest-timer-feasibility.md)
- 验收：[`docs/mvp-acceptance.md`](../docs/mvp-acceptance.md)

## 目录

```
RestTimer/
  README.md
  Shared/
    RestTimerModels.swift          # RestCommand、时长、状态镜像、编解码
    WatchConnectivityBridge.swift  # WCSession：可达/排队/解码错误
  iOS/
    RestTimerApp.swift
    ContentView.swift              # 60/90/120 预设 + 取消 + 连接/镜像 UI
  watchOS/
    RestTimerWatchApp.swift
    RestCountdownView.swift        # deadline 倒计时 + 强触觉 + 取消
    WatchRuntimeSession.swift      # HKWorkout / Extended Runtime stub + TODO
```

**未**提交完整 `.xcodeproj`（Linux/Windows/Cloud 无 Xcode）。Mac 上新建工程挂载源码，或对根目录 `project.yml` 运行 `xcodegen generate`。

## Windows 开发 → Mac 编译

1. 在 Windows 改 Swift / 文档并 push。
2. Mac 拉取分支后按下一节挂源码或 XcodeGen。
3. 真机按验收清单测锁屏、垂腕、取消、触觉。

## 在 Mac / Xcode 中搭建

1. Xcode → **File → New → Project** → **iOS App**（SwiftUI，Swift）。
2. 工程名例如 `RestTimer`；Bundle ID 自定（或与 `project.yml` 一致：`com.yangfitness.RestTimer`）。
3. **File → New → Target** → **watchOS → App**，嵌入 iOS App。
4. `Shared/*.swift` → **iOS + watchOS** Target Membership。
5. `iOS/*.swift` → 仅 iOS；删掉模板重复 `@main` / ContentView。
6. `watchOS/*.swift` → 仅 Watch；同样去掉模板入口。
7. **Signing & Capabilities**（两 target）：
   - 选 Team。
   - 若接 `HKWorkoutSession`：HealthKit + Info.plist 用途说明。
   - Extended Runtime / Background Modes 按所选方案勾选。
8. 真机：iPhone + 配对 Watch Run。

### Capability / Info.plist

| 方案 | 建议 |
|------|------|
| `HKWorkoutSession`（优先） | HealthKit；`NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` |
| `WKExtendedRuntimeSession` | 符合系统允许的 session type；有时长上限 |
| WatchConnectivity | 无需单独 capability；双端 `Activate()` |
| **禁止**以 iPhone 本地通知镜像为到点主路径 | 触觉必须在 Watch 本地 `deadline` 触发 |

## 行为摘要

| 端 | 行为 |
|----|------|
| Watch | `deadline` 计时；UI 剩余秒；到点连续强触觉；「提前结束」/ cancel **不**放行到点触觉 |
| iPhone | 预设 60/90/120；Send start/cancel；展示激活/可达；可选显示 Watch 镜像状态 |
| 不可达 | `transferUserInfo` 排队；横幅说明；到点仍不依赖 Phone |

## 真机验收

[`docs/mvp-acceptance.md`](../docs/mvp-acceptance.md)。模拟器不能替代佩戴触觉。

## Mac 上待补（不阻断本 MVP 结构）

1. 在 `WatchRuntimeSessionCoordinator` 接入真实 `HKWorkoutSession` 或 `WKExtendedRuntimeSession`。
2. 按验收矩阵打勾后再扩非 MVP 功能。

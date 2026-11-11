# yang's Fitness — RestTimer

iOS + watchOS **组间休息计时** 起步骨架：Watch 本地倒计时为事实源，iPhone 经 WCSession 下发 start / cancel / duration，到点在 Watch 播放强触觉。

iOS + watchOS Rest Timer starter: Watch owns the countdown; Phone sends start/cancel/duration over WCSession; completion haptic runs on Watch.

## 快速开始（Mac + Xcode）

1. `git clone https://github.com/1158255546/yang-fitness.git && cd yang-fitness`
2. 用 Xcode 新建 **iOS App**（SwiftUI），再 **File → New → Target → watchOS App**（Embed）。
3. 将 `RestTimer/Shared/*.swift` 勾进 **iOS 与 watchOS** 两个 target；`RestTimer/iOS/*` 仅 iOS；`RestTimer/watchOS/*` 仅 Watch；删除模板重复的 `@main` / ContentView。
4. Signing：选 Team；按需加 Background Modes / HealthKit（见 `RestTimer/README.md`）。
5. 真机：配对的 iPhone + Apple Watch 上 Run（Watch scheme 选真机）。

可选：若已安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，可在仓库根目录执行 `xcodegen generate`（见 `project.yml`）生成 `RestTimer.xcodeproj`，再在 Xcode 中配置签名与 capabilities。

**说明：** Cloud Agent / Linux 环境通常没有 macOS/Xcode，**无法在此编译 watchOS**；请在 Mac 真机构建与验收。

## 文档

| 文档 | 说明 |
|------|------|
| [docs/watch-rest-timer-feasibility.md](docs/watch-rest-timer-feasibility.md) | 可行性结论与架构 |
| [docs/mvp-acceptance.md](docs/mvp-acceptance.md) | 首版验收矩阵（含锁屏/垂腕） |
| [RestTimer/README.md](RestTimer/README.md) | 源码目录与 Xcode 搭建细节 |

## 设计锚点

- Watch = 倒计时事实源；结束触觉在 Watch 本地 `deadline` 触发。
- 不要把 iPhone 本地通知镜像当作到点主路径。
- 锁屏/后台准时依赖 `HKWorkoutSession` 或 `WKExtendedRuntimeSession`（源码中有 TODO）。

## 下一步

按 [MVP 验收清单](docs/mvp-acceptance.md) 在真机打勾；补齐 Watch 侧会话生命周期后再扩非 MVP 功能。

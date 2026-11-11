# yang's Fitness — RestTimer

iOS + watchOS **组间休息计时** MVP：Watch 本地倒计时为事实源，iPhone 经 WCSession 下发 start / cancel / duration，到点在 Watch 播放强触觉。

## Windows → Mac 工作流（推荐）

本仓库可在 **Windows** 上编辑全部 Swift 与文档；**不能**在 Windows / Linux / Cloud Agent 上编译 watchOS。真机构建与触觉验收请到 **Mac + Xcode**。

| 步骤 | 在哪 | 做什么 |
|------|------|--------|
| 1 | Windows | `git clone` / 拉取分支；用 Cursor/VS Code 改 `RestTimer/**/*.swift`、文档 |
| 2 | Windows | commit + push；开/更新 PR（无需 `.xcodeproj`） |
| 3 | Mac | 拉取同一分支；按下方「Mac + Xcode」生成或挂载工程 |
| 4 | Mac | 配置 Signing / Capabilities；真机 iPhone + Watch Run |
| 5 | Mac | 按 [`docs/mvp-acceptance.md`](docs/mvp-acceptance.md) 打勾 |

**说明：** 仓库**不**提交完整 `.xcodeproj`（无 Xcode 的环境无法可靠生成）。用手册步骤或 Mac 上的 XcodeGen。

## 快速开始（Mac + Xcode）

1. `git clone https://github.com/1158255546/yang-fitness.git && cd yang-fitness`
2. 用 Xcode 新建 **iOS App**（SwiftUI），再 **File → New → Target → watchOS App**（Embed）。
3. 将 `RestTimer/Shared/*.swift` 勾进 **iOS 与 watchOS** 两个 target；`RestTimer/iOS/*` 仅 iOS；`RestTimer/watchOS/*` 仅 Watch；删除模板重复的 `@main` / ContentView。
4. Signing：选 Team；按需加 Background Modes / HealthKit（见 `RestTimer/README.md`）。
5. 真机：配对的 iPhone + Apple Watch 上 Run（Watch scheme 选真机）。

可选：若已安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，在仓库根执行 `xcodegen generate`（见 `project.yml`）生成 `RestTimer.xcodeproj`，再配置签名与 capabilities。

## MVP 能力

- **Watch**：`deadline` 本地倒计时；UI 显示剩余秒；到点强触觉；取消不触发到点触觉。
- **iPhone**：60 / 90 / 120s 预设；WCSession 发送 start/cancel；展示连接状态与 Watch 镜像（若回传）。
- **桥接**：`WatchConnectivityBridge` 编码/解码命令与状态；不可达时 `transferUserInfo` 排队并提示。
- **会话**：`WatchRuntimeSessionCoordinator` 为 `HKWorkoutSession` / `WKExtendedRuntimeSession` 的 Mac/真机 stub（含 TODO）。

## 文档

| 文档 | 说明 |
|------|------|
| [docs/watch-rest-timer-feasibility.md](docs/watch-rest-timer-feasibility.md) | 可行性结论与架构 |
| [docs/mvp-acceptance.md](docs/mvp-acceptance.md) | 首版验收矩阵（含锁屏/垂腕） |
| [RestTimer/README.md](RestTimer/README.md) | 源码目录与 Xcode 搭建细节 |

## 设计锚点

- Watch = 倒计时事实源；结束触觉在 Watch 本地 `deadline` 触发。
- 不要把 iPhone 本地通知镜像当作到点主路径。
- 锁屏/后台准时依赖 `HKWorkoutSession` 或 `WKExtendedRuntimeSession`（源码中有 TODO，需在 Mac 真机补齐）。

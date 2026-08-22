## 项目定位

Roster 是 Swift 原生 macOS App，不是 Web/Electron 项目。默认技术栈是 Swift 6、SwiftUI、AppKit、Swift Package Manager、Contacts、Speech、AVFoundation 和 sqlite3。

- `Package.swift` 是构建入口。
- `Sources/RosterCore/` 放纯领域逻辑和 Contacts 模型。
- `Sources/RosterApp/` 放 SwiftUI/AppKit 应用层、本地存储、服务和界面。
- `Tests/RosterCoreTests/`、`Tests/RosterAppTests/` 放 Swift Testing 测试。
- `scripts/build-app.sh` 构建 `.app`，`scripts/update-local-package.sh` 构建 release 并安装到 `/Applications/Roster.app`。

## 工作流程

1. 每次结束工作，返回结果后，告诉我你使用了什么skills。
1. 使用 ponytail skills 精简代码，精简你的回复。
1. 遇到需求的时候先考虑如何用最小的代码去实现，先去联网搜索，如果有开源的库、项目能够实现，用现成的代码。
1. 对 UI 的改动要与 SwiftUI 原生体验、现有 `RosterTheme`、其它页面和 macOS HIG 匹配。
1. 测试完、构建完清理掉进程，避免进程的占用。
1. 每次新的改动完成后，先运行 `scripts/update-local-package.sh` 做一次本地发布。
1. 新的一轮改动验证前也先跑一次 `scripts/update-local-package.sh`。
1. 涉及 macOS 拖拽交互时，按 `docs/e2e/macos-drag-and-drop.md` 的方案运行对应 e2e。
1. 与客户的对话要把需求明确清楚，搞清楚需求的边界，再开始做代码。

## 多 Agent 协作流程

多 Agent 任务由 Orca 负责编排生命周期，Pi 作为统一 worker 壳连接不同模型、工具权限和当前 Swift 项目上下文。模型只负责角色分工，不决定流程 gate；UI demo、需求变更、架构边界和高风险验证必须停下给用户确认。

- 派发 worker 前必须先跑模型 preflight：`pi --list-models kimi`、`pi --list-models deepseek`、`pi --list-models cc-switch-claude`、`pi --list-models cc-switch-codex`。目标模型别名不可见时先修配置，不带错误模型开工。
- 默认模型路由：Kimi 做 SwiftUI/macOS UI 方案和 demo；Claude 4.8 做需求/架构审查；DeepSeek Flash 做快速只读检查；便宜 Codex 做明确需求后的 Swift 实现；Codex 5.6 做最终只读实现审查。
- 只读 worker 工具限制为 `read,bash,grep,find,ls`，`bash` 只允许 Orca lifecycle 命令和只读命令；实现 worker 用默认工具但只能改 coordinator 指定范围；验证 worker 只跑验证、不改源码。
- `pi --tools` 不能做路径级写入硬限制。路径边界靠 prompt、独立 worktree、最终 `git diff` 复核和 worker 释放/回收兜底。
- 每个 worker 的 `worker_done` 必须写：`outcome`、`summary`、`files_read`、`files_modified`、`tests_run`、`risks`、`user_decisions_needed`、`next_owner`。失败必须用 failed，需要用户确认必须用 needs_user 并停下。
- UI 相关需求默认先过 demo gate，除非用户明确说需求和验收已确认、直接实现。影响页面结构、核心工作流、视觉语言或用户心智模型时，先输出 SwiftUI 原生方案或轻量 demo，coordinator 给用户确认后才能改真实 app。
- SwiftUI UI 方案必须先读相关视图、`Sources/RosterApp/Theme/RosterTheme.swift`、`Sources/RosterApp/RosterLocalization.swift` 和邻近组件；不引入 Web/Electron/Tailwind/shadcn 等非原生方案。
- Worktree 策略：只读 worker 用 current worktree；单个实现 worker 可用 current；多个实现 worker 并行必须用独立 worktree；依赖用户未提交改动时只允许一个写入 owner。
- 验证按改动面选择：纯 `RosterCore` 逻辑跑 focused `swift test --filter ...`，必要时跑 `env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build"`；SwiftUI/App 状态改动跑相关 `RosterAppTests`、`swift build` 或 `scripts/build-app.sh`；Contacts/AppKit/Speech/AVFoundation、SQLite、本地权限和 `.app` 行为必须用真实 macOS app 或专用 e2e 验证。
- 涉及本地存储或 sqlite3 schema 时，只做最小迁移，确保旧数据可读；涉及 Contacts 写回时必须保护用户通讯录数据，不能绕过确认和权限边界。
- 失败恢复：worker 超时先读终端和 dispatch 状态；实现失败让原 worker 修一次，第二次失败升级 Claude 4.8 或 DeepSeek Pro 诊断；UI demo 不满意回到 demo 阶段，不创建实现任务；审查发现 Important/Critical 必须修复后再交付。
- 最终回复必须包含实际使用的模型和 worker、每个 worker outcome、修改文件、验证命令和结果、未验证项、用户确认过的 gate、worker/dev server/browser 是否已清理，以及只和当前任务直接相关的后续建议。

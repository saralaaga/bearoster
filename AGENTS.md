## 项目定位

Roster 是 Swift 原生 macOS App，不是 Web/Electron 项目。默认技术栈是 Swift 6、SwiftUI、AppKit、Swift Package Manager、Contacts、Speech、AVFoundation 和 sqlite3。

- `Package.swift` 是构建入口。
- `Sources/RosterCore/` 放纯领域逻辑和 Contacts 模型。
- `Sources/RosterApp/` 放 SwiftUI/AppKit 应用层、本地存储、服务和界面。
- `Tests/RosterCoreTests/`、`Tests/RosterAppTests/` 放 Swift Testing 测试。
- `scripts/build-app.sh` 构建 Bearoster `.app`（debug 在 `.build/`，release 在 `dist/` 并生成 zip）；`scripts/update-local-package.sh` 安装到 `/Applications/Bearoster.app`，还会删除旧 `/Applications/Roster.app`、`/Applications/Birthday.app`。这些不是无副作用的测试命令，执行前遵守下方本地安装门禁。

## 部署、签名与本地安装约束（2026-09-11）

- Coordinator、worker 和独立 Agent 在资源初始化、签名、公证、分发或密钥操作前，完整读取 `/Users/carlos/.agents/deployment-policy.md`（版本 2026-09-06）。协议不可用时停止敏感执行并报告 blocked；普通本地无秘密开发与 focused 测试可继续。旧文档/脚本能运行不构成发布授权。
- **当前状态（2026-09-24）：MAS 发布走本机人工两步，Agent 仍不签名不上传。** 团队 `BC4LLSRW92` 下已有 Developer ID Application、Apple Distribution、Mac Installer Distribution 三张证书与一份 Mac App Store 描述文件。发布流程 = 用户本人跑 `scripts/build-mas-pkg.sh` 出签名 pkg + 本人用 Transporter/altool 上传，之后 ASC 元数据与提交审核可由 Agent 在用户登录的浏览器会话里代操作。GitHub Environment 审批门已建成但因免费版不支持 required reviewers 搁置（`release.yml`/`website.yml` 与配置脚本保留未激活，升级 Pro 后可启用）。本节是 Agent 行为规范，不是 OS/Keychain/CI 强制隔离。
- 已知标识：可执行名 Bearoster；版本来源 `Packaging/VERSION`；正式 bundle ID `com.bearoster.app`（已在团队 BC4LLSRW92 下注册为 App ID）；debug 构建仍用 `dev.local.roster` 以保住本机既有的 Contacts/TCC 授权。App Store Connect 应用记录已建立（Bearoster / macOS / 简体中文 / SKU `BEAROSTER001`，团队 BC4LLSRW92）；面向上架的文案、法务页、问卷答案与截图在 `AppStore/`。TestFlight/官网分发账号与存储资源仍未核实，须单独确认，不猜测或借用其它项目身份。审批门与哈希校验位于 `scripts/release/`，边界与仍然 blocked 的部分见 `docs/release-protected-executor.md`。
- 远端是 `https://github.com/saralaaga/bearoster`（private）。`.github/workflows/ci.yml` 只跑 Swift 测试与 macOS/iOS shared target 构建，不是签名/发布入口。push/merge 前核实远端是否另有自动签名/发布；未知则先确认。
- 打包脚本：`scripts/build-app.sh` 出直发产物（release 强制要求 Developer ID Application，找不到直接报错；debug 自动用 Apple Development，无则 ad-hoc），`scripts/build-mas-pkg.sh` 出 Mac App Store 的签名 `.pkg`。无凭据本地打包显式用 `ROSTER_CODESIGN_IDENTITY=-`。发布凭据存于自托管 Infisical 的 `Bearoster`/`prod`（`/notary`、`/signing`），证书私钥在签名主机的登录钥匙串里。不要在持有发布秘密的 Shell 运行构建或项目钩子。
- 本地安装与外部分发分开：执行 `scripts/update-local-package.sh` 前须取得明确范围授权（可以是本轮会话的有限授权），说明它会修改版本、终止 Bearoster/Roster 进程、替换 Bearoster 并删除上述旧 App。用户未授权删除旧 App 或目标/副作用变化时停止，不默认接受脚本全部动作；默认先做不安装的验证。文档/只读审查任务不得自动安装或签名。
- 本地安装须先确认可恢复的旧安装包/数据保护方式；未经明确授权不得删除用户数据库、重置系统权限、写回真实通讯录或清理用户正在使用的进程。沿用原 Contacts/SQLite/原生 e2e 验证要求，不把打包成功等同于数据安全。
- 外部上传、TestFlight/App Store 发布、Developer ID/分发证书签名、公证须走经验证的受保护入口：构建无发布秘密，签名/上传/批准身份分离，密钥仅供受信步骤。普通 Agent 不得持有签名私钥、Apple 账号管理/API 管理凭据、广域 BWS Token、其它项目 SSH/云密钥，不得向任意子进程共享宿主 Keychain/home。
- 部署 Task 必须带共享协议路径/版本、项目/环境/资源或分发目标、允许/禁止动作、入口和身份引用、commit/产物摘要/版本、授权期限、审查、验证与回滚。独立人类审批须由执行器验证，业务 Agent 不能自批或修改生效策略；入口缺失先计划建设，不能回退手工持密钥脚本。
- 不打印秘密、完整环境、vault/认证响应；不把整库注入 Shell，不用 xtrace/env/set/declare 输出凭据。泄露/越权/缺权限时停止受影响操作、脱敏通知用户，不转发原始日志、不尝试旧 key。恢复按共享事件流程批准。
- 日常开发与外部分发门禁不混淆：本地测试无需云发布器，候选 zip 不代表已发布；线上/商店状态需实际 provider 证据。单独终端/worktree 不等于证书或用户数据隔离。

## 工作流程

1. 每次结束工作，返回结果后，告诉我你使用了什么skills。
1. 使用 ponytail skills 精简代码，精简你的回复。
1. 遇到需求的时候先考虑如何用最小的代码去实现，先去联网搜索，如果有开源的库、项目能够实现，用现成的代码。
1. 对 UI 的改动要与 SwiftUI 原生体验、现有 `RosterTheme`、其它页面和 macOS HIG 匹配。
1. 测试完、构建完清理掉进程，避免进程的占用。
1. 每次改动先按改动面运行 focused 测试/构建；需要 `.app` 验证时可显式 ad-hoc 本地打包。`scripts/update-local-package.sh` 仅在上方本地安装门禁满足后运行，不再每轮自动执行。
1. 新一轮验证不要自动递增版本、关闭 App、覆盖安装或清理旧 App；纯文档和只读任务只验证对应文件。
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

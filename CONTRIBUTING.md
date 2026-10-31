# 贡献指南

感谢关注 Bearoster（仓库内亦称 Roster / 名册）。本项目是 **local-first** 的 macOS 通讯录管理应用：优先在本机读写 Contacts，不把用户通讯录当作可随意改写的试验场。

## 语言

- **GitHub Issues / PR 的标题与正文请使用中文。** 路径、命令、SHA、URL、标签名、代码标识保持原样。
- 代码注释与面向用户的 UI 字符串遵循仓库现有约定（中英本地化见 `RosterLocalization`）。

## 开发环境

- macOS 14+
- Xcode / Swift 工具链（Swift 6，Swift Package Manager）
- 入口：`Package.swift`

## 构建

本地生成 `.app`（debug，默认可 ad-hoc）：

```bash
scripts/build-app.sh
```

或显式 ad-hoc：

```bash
ROSTER_CODESIGN_IDENTITY=- scripts/build-app.sh debug
```

产物通常在 `.build/`（具体文件名以脚本输出为准）。**不要**在未获明确授权时运行 `scripts/update-local-package.sh`（会改版本号、替换 `/Applications` 下的 App）。

Release / Mac App Store 签名与上传属于受保护发布路径：普通贡献与 Agent **不要**持有或提交签名私钥、描述文件或 ASC API 密钥。详见仓库 `AGENTS.md` 中的部署与签名约束（高层门禁；具体密钥位置不在公开文档展开）。

**公开克隆不需要任何签名材料。** `swift test` 与 `scripts/build-app.sh`（可用 `ROSTER_CODESIGN_IDENTITY=-`）即可本地验证。仓库中少数维护者脚本（如 `scripts/build-mas-pkg.sh`、`scripts/release/bootstrap-release-secrets.sh`）把 `$HOME/private_keys/...` 当作本机默认路径，可用 `ROSTER_MAS_P12` / `ROSTER_MAS_PROFILE` 等环境变量覆盖；这些路径只存在于维护者机器，**不是**公开贡献的前置条件，也没有密钥文件被提交到仓库。

## 测试

全量测试：

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build"
```

按改动面跑 focused 测试，例如：

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build" --filter RosterCoreTests
```

涉及 Contacts 写回、Keychain、权限或真实 `.app` 行为时，须用隔离的测试联系人 / 本机验证，**不得**拿用户现有通讯录做破坏性试验。

## Pull Request

- 从最新 `main` 拉分支；PR 描述用中文写清动机、改动与验证命令。
- 保持改动面小；UI 变更对齐现有 `RosterTheme` 与 macOS HIG。
- **禁止**在 PR 中提交密钥、证书、`.p12` / `.p8`、provisioning profile、真实个人数据、私有收件箱或家目录绝对路径中的敏感运维地图。
- CI（`.github/workflows/ci.yml`）应保持绿色；不要依赖私有密钥才能通过测试构建。

## Issue

- 用中文描述复现步骤、期望与实际结果；附上相关日志时请脱敏。
- 功能需求请说明边界（例如是否影响 MAS 上架或开源公开范围）。目标跟踪见 `#7`（开源）、`#8`（Mac App Store）。

## 行为与隐私

- 尊重 Contacts / Speech / 麦克风等系统权限；文案与行为须与 `AppStore/` 及隐私说明一致。
- 不要在示例、截图、测试夹具中放入真实姓名、电话或邮箱；使用合成数据（如 `555` / `13800138000` 风格号码）。

## 需要帮助时

先读 `README.md` 与 `AGENTS.md`。不确定是否触及签名、上传或密钥时，先开 Issue 询问，不要自行「试一下」发布路径。

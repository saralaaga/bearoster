# 发布路径（2026-09-24 起：本机人工两步）

状态：**当前采用本机人工发布：用户本人跑构建签名 + 本人上传。GitHub 审批门方案已建成但因免费版不支持 required reviewers 而搁置（文件保留，未激活）。**
适用策略：本机部署策略文档（默认 `$HOME/.agents/deployment-policy.md`，版本 2026-09-06）
最后更新：2026-09-24

## 当前发布流程

人工即审批：特权步骤由用户本人在自己终端完成，密钥全程不离开本机。

```bash
# 1) 用户本人运行：从钥匙串签名身份出 MAS .pkg
scripts/build-mas-pkg.sh            # 产物在 dist/mas/Bearoster-<版本>.pkg
```

```text
# 2) 用户本人上传，二选一：
#    a) Transporter App：把 pkg 拖进去，点 Deliver
#    b) xcrun altool --upload-app --type macos -f dist/mas/Bearoster-<版本>.pkg \
#         -u <AppleID> -p <App 专用密码>
```

之后在 App Store Connect 选 build、提交审核（可由 Agent 在浏览器代操作，账号会话属于用户）。

理由（为什么这道人工门对本项目足够）：签名证书与 ASC key 本来就在本机，GitHub 门不消除本机暴露面、反而要私钥离开本机；上架前有 App Review 强制外部门；仓库单人维护，Agent 已拥有全部源码写入权，签名步骤不是信任链最薄弱环节。失去的只是「独立审批记录 + 防自批」的纵深， consciously accepted。

Agent 边界不变：不执行分发证书签名、不上传构建、不持有 Apple 凭据；只做无凭据构建、测试、ASC 元数据操作。

## 为什么 GitHub 门被搁置

`release.yml`/`website.yml` 的审批门依赖 Environment required reviewers，2026-09-24 实测 GitHub 免费版返回 422 不支持。升级 Pro/Team 后重跑 `scripts/release/configure-release-gate.sh` + `scripts/website/configure-deploy-gate.sh` 即可激活（脚本保留未删）。届时密钥需 bootstrap 进 GitHub secrets——是否接受密钥离机由用户再决定。

## 历史：审批记录 + 哈希门（本地纵深，仍然可用）

代码在 `scripts/release/`。

发布动作需要三件事同时成立：

1. 产物可追溯到确定的 commit；
2. 有独立于执行者的人批准过这个**具体产物**；
3. 执行者拿不到「自己批准自己」的能力，也拿不到用不到的凭据。

第 1 件已经做完了。第 2、3 件在**只能改仓库文件**的前提下做不到——任何能写仓库的 Agent 都能写一份看起来合法的审批文件。所以下面把已经建成的门、还没建成的门、以及建成它需要的具体步骤分开写清楚。

## 已经建成：审批记录 + 哈希门

代码在 `scripts/release/`。

| 脚本 | 谁运行 | 作用 |
|---|---|---|
| `build-release-artifact.sh` | 任何人 | 从**干净工作树**构建候选产物，写 `manifest.txt`，绑定 commit / 版本 / 目录哈希。不碰任何发布凭据 |
| `request-approval.sh` | **只能由人运行** | 交互式确认，写 `release/approvals/<时间>-<动作>.txt`。非交互终端直接拒绝 |
| `verify-approval.sh` | 任何人（只读） | 校验：commit 与 manifest 一致、工作树干净、存在且**唯一**未过期的审批记录、审批记录的 `tree-sha256` 与 manifest 一致 |
| `execute-release.sh` | 任何人 | 先跑完整门，门通过后**停下**并报 blocked |

审批记录是纯文本、可入库、非秘密的审计材料：

```
approval-version: 1
action: submit-for-review
target: app-store-connect
approver: Carlos <you@example.com>
approved-at: 2026-09-11T15:00:00Z
expires-at: 2026-09-14T15:00:00Z
commit: f8425b5…
marketing-version: 1.0
artifact: Bearoster.app
tree-sha256: 9c1f…
evidence: 查看了 1.0 的商店文案与截图，本地跑通沙盒构建
```

默认有效期 72 小时（`ROSTER_APPROVAL_HOURS` 可改）。换了产物或 commit，旧审批自动失效。

### 这层防护的边界（不要高估）

- 能挡住的：误操作、忘了审批、拿旧产物配新 commit、审批过期后继续用。
- **挡不住的**：任何能写仓库或写 `release/approvals/` 的 Agent 都能伪造一条记录。`approver:` 字段是自报的，没有密码学意义。
- 因此这层是**纵深防御**，不是策略要求的「独立审批入口」。

## 已建成但搁置：GitHub Actions Environment 入口（方案 A）

`.github/workflows/release.yml` 与网站部署门（`docs/website-deploy-gate.md`）同一模式：

- **candidate job（无任何秘密）**：校验 dispatch 的版本号与 `Packaging/VERSION` 一致，跑全量测试，用 `build-release-artifact.sh direct` 出 ad-hoc 候选产物 + manifest，作为 workflow artifact 上传。这是审批人看到并被绑定到的产物。
- **sign-and-upload job（`environment: app-store-release`）**：只有你在 GitHub 上点 Approve 后才运行。从 Environment secrets 导入 Apple Distribution / Installer 身份与描述文件，跑 `scripts/build-mas-pkg.sh` 出签名 `.pkg`，再用 ASC API key 通过 `xcrun altool --upload-app` 上传 App Store Connect。结束即删除专用钥匙串。

Environment 限制为 `main` 分支 + 你本人是唯一 required reviewer。Agent 可以改 workflow、可以 push，但无法代替你点 Approve。

### 一次性配置（只能你本人做）

```bash
scripts/release/configure-release-gate.sh      # 创建 app-store-release 审批门
scripts/release/bootstrap-release-secrets.sh   # 写入六个 Environment secrets
```

第二个脚本交互式写入 GitHub Environment 所需的签名与 ASC 上传秘密，不打印任何值。秘密来源为 Infisical（Bearoster/`prod`）与签名主机本地材料；具体条目与路径见私人 runbook，不在仓库展开。

**代价与边界**：启用该门意味着部分发布秘密会离开本机进入 GitHub Environment secrets，换来审批/执行身份分离。轮换时 GitHub 与本机两侧都要更新；细节见私人 runbook。

### 发布流程

1. `main` 上确认 `Packaging/VERSION` 是要发的版本（build number 递增过）。
2. GitHub → Actions → **App Store release** → Run workflow，输入版本号。
3. candidate job 出产物后，GitHub 请求你审批 deployment；你核对版本与候选 manifest 后 Approve。
4. sign-and-upload job 签名并上传；之后在 App Store Connect 里选 build 并提交审核（提交审核这一步仍由你在网页上完成）。

回滚：上传只是把 build 送进 ASC，不会自动发布；发错版本就在 ASC 丢弃该 build，修 VERSION 后重新走流程。

### 方案 B（未采用）

本机独立审批器 + 独立钥匙串。没有 OS 级用户/机器隔离就不成立（Agent 能以同一用户身份访问宿主 Keychain），成本更高，作为备选记录。

**本地 `execute-release.sh` 仍按设计停在特权步骤前（退出码 3）。本地路径不再扩展；外部执行一律走上面的 GitHub 入口。**

## 密钥现状与轮换

发布秘密存放在 **Infisical（Bearoster/`prod`）** 与 **签名主机 Keychain**；导出备份与口令只存在所有者的私人保管位置。仓库与公开文档不记录具体文件路径、密钥名清单或备份脚本位置——见私人 runbook。

轮换时按策略要求走：先在新消费者上切换，再在 provider 侧吊销旧 key，并验证旧身份确实被拒。

## 日常怎么用

```bash
# 1) 从干净工作树出候选产物（无凭据）
scripts/release/build-release-artifact.sh direct

# 2) 由人批准这个具体产物
scripts/release/request-approval.sh \
  --artifact release/artifacts/<commit>/Bearoster.app \
  --action submit-for-review \
  --target app-store-connect

# 3) 只校验，不做任何副作用
scripts/release/verify-approval.sh \
  --manifest release/artifacts/<commit>/manifest.txt \
  --action submit-for-review \
  --target app-store-connect

# 4) 走到特权步骤前会停下并报 blocked
scripts/release/execute-release.sh \
  --manifest release/artifacts/<commit>/manifest.txt \
  --action submit-for-review \
  --target app-store-connect
```

`--dry-run` 在第 4 步会把特权步骤原样打印出来，仍然不签名、不上传。

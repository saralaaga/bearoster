# 受保护执行器与人工审批入口

状态：**部分建成。外部上传/提交仍然 blocked。**
适用策略：`/Users/carlos/.agents/deployment-policy.md`（版本 2026-09-06）
最后更新：2026-09-11

## 这份文档解决什么问题

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

## 还没建成：真正的强制边界

策略要求入口具备「普通 Agent 无法授予自己更大身份、无法自批」的性质，且由 OS/IAM/CI 强制，而不是靠脚本自觉。两个可选方案：

### 方案 A（推荐）：GitHub Actions Environment + Required Reviewers

- 新建 workflow `release.yml`，用 `environment: app-store-release`。
- 在该 Environment 上设置 **Required reviewers**（必须是你本人，不能是机器人账号）。
- Apple 凭据只存在于该 Environment 的 secrets 里，workflow 用 `id-token` / Environment secrets 读取。
- Agent 可以改 workflow 文件、可以 push，但**无法自我批准**待执行的 deployment——GitHub 会拦住，直到你点 Approve。
- 构建与签名分离：普通 CI job 只构建、上传候选产物；签名/notarize/上传放在需要 Environment 审批的 job 里。

这条路的代价：Apple Distribution 私钥和 notary key 要存进 GitHub secrets。密钥离开本机，换来的是真正的双人（人 + 机器）分离。

### 方案 B：本机独立审批器 + 独立钥匙串

- 单独的、Agent 无写权限的用户账号或机器，持有专用钥匙串，`setup-signing-keychain.sh` 已经把私钥搬进需交互解锁的钥匙串，是这条路的第一步。
- 需要额外解决：Agent 能以同一用户身份访问宿主 Keychain。没有 OS 级用户/机器隔离就不成立。
- 成本比方案 A 高，隔离强度取决于你怎么配。

**在 A 或 B 任一建成并验证之前，`execute-release.sh` 会一直返回 blocked（退出码 3），这是设计如此。**

## 密钥现状与轮换

| 项目 | 位置 | 备注 |
|---|---|---|
| Apple Distribution + Mac Installer Distribution 私钥 | 本机登录钥匙串（可选迁到专用钥匙串） | `~/private_keys/p12/bearoster-mas-identities.p12` 是导出备份，有口令 |
| p12 口令 | 用户的密码管理器 | **不在** Infisical 里 |
| App Store Connect API Key（`.p8`） | Infisical `Bearoster`/`prod` `/notary` | 本机已无明文副本 |
| Infisical `ENCRYPTION_KEY` | 用户密码管理器 | 唯一单点故障，必须有离线备份 |

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

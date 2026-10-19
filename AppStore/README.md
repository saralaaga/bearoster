# App Store 上架材料

上架 App Store 需要的文案、法务页、问卷答案和截图都在这里。所有内容与当前代码行为一致，可以直接复制到 App Store Connect。

## 目录

| 路径 | 内容 | 复制到哪里 |
|---|---|---|
| `metadata/zh-Hans.md` | 简体中文：名称、副标题、关键词、宣传文本、描述、新内容、URL、版权、分类 | App Store Connect → App 信息 / 版本信息 |
| `metadata/en-US.md` | 英文同上 | 同上（en-US 本地化） |
| `questionnaires/app-privacy.md` | App 隐私问卷答案 | App Store Connect → App 隐私 |
| `questionnaires/age-rating.md` | 年龄分级问卷答案 | App Store Connect → 年龄分级 |
| `legal/privacy-policy.zh-Hans.md` | 隐私政策正文（中文） | 发布到 `https://bearoster.com/privacy` |
| `legal/privacy-policy.en.md` | 隐私政策正文（英文） | 发布到 `https://bearoster.com/en/privacy` |
| `legal/support.zh-Hans.md` | 支持页正文（中文） | 发布到 `https://bearoster.com/support` |
| `legal/support.en.md` | 支持页正文（英文） | 发布到 `https://bearoster.com/en/support` |
| `screenshots/01-calendar.png` … `06-sync-history.png` | 6 张 macOS 截图，2560×1600（16:10，符合 App Store 要求） | App Store Connect → 版本信息 → 预览与截图 |

## 截图是怎么来的

`scripts/capture-store-shots.sh` 用 debug 构建 + `--roster-e2e store <视图>` 夹具渲染，数据来自 `Sources/RosterShared/RosterE2EFixtures.swift` 里的虚构演示联系人（陈嘉禾、Amelia Hart……），**不是**真实通讯录。

夹具读取路径包在 `#if DEBUG` 里，正式构建不含这条分支。要重拍：

```bash
ROSTER_CODESIGN_IDENTITY=- scripts/build-app.sh debug
scripts/capture-store-shots.sh
```

需要给调用进程开屏幕录制和辅助功能权限。换版本文案或改了界面后重跑一次即可。

## 提交前 checklist

仓库内已经做完的：

- [x] 版本号 `1.0`（`Packaging/VERSION`），与 App Store Connect 的版本一致
- [x] App 图标、`PrivacyInfo.xcprivacy`、沙盒 entitlements 随包分发
- [x] 商店文案（中英）、隐私政策、支持页、两份问卷答案、6 张截图
- [x] 审批门与哈希校验（`scripts/release/`，见 `docs/release-protected-executor.md`）

需要你本人做的：

- [ ] 部署 `website/` 后确认 `/privacy`、`/support`、`/en/privacy`、`/en/support` 返回独立法务页（本地 `npx wrangler pages deploy website --project-name=bearoster --branch=main` 部署；2026-09-24 网站门因免费版不支持 required reviewers 搁置，见 `docs/website-deploy-gate.md`）
- [x] 在 App Store Connect 填写文案并跑完两份问卷（2026-09-24 由 agent 经 ego 浏览器完成：中英文案/关键词/URL/版权、6 张截图、隐私 Data Not Collected 已发布、年龄分级 4+、内容权利无第三方内容；余下两件小事见下）
- [ ] ASC 版本页把 `01-calendar` 截图拖到第一位（合成拖拽驱动不了 ASC 的排序组件，顺序当前为 02,03,01,04,05,06）
- [ ] ASC 版本页 App Review Information 填联系人姓名/电话/邮箱（个人联系方式，agent 不代填）
- [x] 在 Cloudflare Email Routing 把 `support@bearoster.com` 转发到 `saralaagarwal1990@gmail.com`（2026-09-24 完成：规则已启用，MX/SPF 已生效，目标邮箱此前已验证）
- [ ] 备份 Infisical `ENCRYPTION_KEY`（`~/infisical/backup-infisical.sh`）
- [ ] p12 口令存进密码管理器

仍然是 blocked 的：

- [ ] **上传构建**。2026-09-24 决定不走 GitHub 审批门（免费版不支持 required reviewers），改为本机人工两步：用户本人跑 `scripts/build-mas-pkg.sh` 出签名 pkg，再用 Transporter 或 `xcrun altool --upload-app` 上传，见 `docs/release-protected-executor.md`。Agent 不执行签名与上传
- [ ] 欧盟交易商状态（只有面向欧盟上架时才需要）

## 免费发布

免费发布，不做 App 内购买；项目已开源，暂无内购计划。商店文案和描述里没有订阅相关内容。

## 待确认

- 商店名称按语言本地化：zh-Hans 使用「蓝熊名册」，en-US 使用 `Bearoster`。运行时界面已有对应本地化；如后续要求安装后的应用名也完全跟随语言，再补 `InfoPlist.strings`。

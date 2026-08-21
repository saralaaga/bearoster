# 设置页（权限与设置）布局调整方案

**日期**: 2026-08-13
**版本**: 0.2.0 (build 23)
**范围**: `Sources/RosterApp/Views/Settings/PermissionsSettingsView.swift` 单文件，约 30 行改动
**参考截图**: `.tmp-screenshots/settings-full.png`

---

## 一、问题诊断

### 1. 控件未对齐（核心问题）

`SettingsRow`（`PermissionsSettingsView.swift:507-537`）当前实现：

```swift
HStack(alignment: .center, spacing: 18) {
    VStack(alignment: .leading, spacing: 3) { title; detail }
        .layoutPriority(1)
    accessory
        .frame(alignment: .trailing)   // ❌ 无宽度约束，无效
}
```

文字块与控件之间**没有 `Spacer`**，`.frame(alignment: .trailing)` 在无宽度约束时不产生任何对齐效果。控件紧跟文字之后，x 位置随行文字长度漂移：

- "显示年龄"的 Toggle 在 x≈255
- "界面语言"的 Picker 在 x≈375
- "即将到来"的 Stepper 又在另一个位置

`contactFieldsSection`（:137）和 `dataSourceSection`（:235）试图用 `.frame(width: 64)` 补救，但没有 Spacer 同样无效。

### 2. 重复文案

| 位置 | 重复内容 | 代码位置 |
|------|----------|----------|
| 分组访问卡片 | "通讯录分组访问"出现 3 遍（section 标题 + 行标题 + Picker label） | :50, :53, :56 |
| 界面语言行 | "界面语言"出现 2 遍（行标题 + menu Picker label）；detail "System" 与 Picker 显示重复 | :90, :91, :93 |
| 显示年龄行 | detail "年龄" 是标题复述 | :105 |
| 权限卡片 | 标题"已获得通讯录访问权限"与绿色 pill 文字完全相同 | :261-266 |
| 版本号 | 页面标题栏与权限卡片右下角各出现一次 | :300-308 |

根因：`.pickerStyle(.menu)` / `.pickerStyle(.segmented)` 会把 Picker 的 label 渲染在控件左侧。

### 3. "即将到来"值与控件分离

Stepper 是 `labelsHidden`（:114-116），值 "30 天" 只能显示在左侧 detail 里，值和调节控件分离在卡片两端。

### 4. 版本号位置不合理

版本块塞在权限卡片右下角（:300-308），与"前往系统设置"按钮挤在同一行，左右内容不相关，视觉重心失衡。

---

## 二、调整方案

统一为 macOS 系统设置的标准形态：**每行「左：标题 + 说明 / 右：控件」，控件钉在卡片右缘形成一条 trailing 对齐线**。

### 1. 修复 SettingsRow（一处改动，全页对齐）

```swift
HStack(alignment: .center, spacing: 18) {
    VStack(alignment: .leading, spacing: 3) { … }
    Spacer(minLength: 0)          // 新增
    accessory                     // 去掉 .frame(alignment: .trailing)
}
```

同时删除 :137、:235 两处补丁式 `.frame(width: 64, alignment: .trailing)`。

### 2. 去重

- 两个 Picker 加 `.labelsHidden()`（:56、:93）。
- 删除 `SettingsStatusPill`（:263-266）：状态图标（绿勾）+ 标题已足以表达状态。
- 语言行 `detail` 置空（:91）；年龄行 `detail` 置空或改为说明文字（:105）。
- 分组访问行标题改为说明性文字（如"选择可访问的通讯录范围"），或 detail 留空（:53）。

### 3. "即将到来"值挪到控件侧

```swift
HStack(spacing: 8) {
    Text(upcomingRangeDisplay)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .monospacedDigit()
    Stepper("", value: $model.upcomingRange, in: 7...120, step: 7)
        .labelsHidden()
}
```

行 detail 改为说明或置空。

### 4. 版本号移入独立"关于"区

- 删除权限卡片右下角的版本块（:300-308）及 `versionDisplay`（:315-320）。
- 页面底部新增 about section：

```swift
private var aboutSection: some View {
    SettingsSection(title: model.l10n(.about)) {
        SettingsRow(title: model.l10n(.version), detail: "") {
            Text(versionDisplay)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
```

- `versionDisplay` 上移为 `PermissionsSettingsView` 的私有属性。
- `RosterRootView.swift:210-215` 标题栏的版本号保留（`versionDisplay` 重复逻辑可后续合并到 model）。
- 本地化：`RosterLocalization.swift` 需新增 `.about` key（关于 / 關於 / About）。

### 5. 页面结构（调整后）

```
通讯录          → 权限状态卡片（图标 + 标题 + 说明 + 按钮行）
通讯录分组访问   → segmented（仅授权后显示）+ 分组勾选列表
设置            → 界面语言 / 显示年龄 / 即将到来（控件全部 trailing 对齐）
联系人字段访问   → 读取扩展字段 + 说明
语音日期输入     → 输入框 + 按钮行
支持的历法       → 四历法色点
数据来源         → macOS 通讯录
关于            → 版本号（新增，置于页面末尾）
```

---

## 三、验收标准

- [ ] 所有行的控件右缘在同一 x 坐标（trailing 对齐线）。
- [ ] 任意文本在同一行内不重复出现（Picker label、StatusPill、detail 复述均消除）。
- [ ] "30 天"数值紧贴 Stepper 显示。
- [ ] 版本号只出现在标题栏和"关于"区。
- [ ] 浅色/深色两种模式下卡片描边、分隔线、阴影正常。
- [ ] 三语（简中/繁中/英文）下无截断、无硬编码中文。
- [ ] 构建通过后运行 `scripts/update-local-package.sh` 本地发布并截图验证。

# Roster 代码审查问题与验收清单

> 适用范围：当前 `main` 分支的 RosterCore、RosterShared、RosterApp 和 RosterIOSApp。
> 文档目的：明确仍需处理的问题、修复边界和关闭问题前必须完成的验收。
> 基线：macOS Swift Testing 共 57 个测试通过；iOS `RosterShared` 当前无法编译。

## 1. 使用规则

- 按 P0、P1、P2 顺序实施。P0 涉及数据损坏、持久化可靠性或目标平台构建，不应与纯视觉优化混做。
- 每项修改先补能复现问题的测试，再修改实现；验收记录应包含命令、结果和必要的截图或 Instruments 证据。
- “现有测试通过”不能单独作为关闭标准。必须满足该问题下列出的自动化验收、人工验收和完成标准。
- Contacts 验收只能使用专门创建的测试联系人，不得拿用户现有联系人做破坏性试验。
- SQLite schema 变更必须从旧版本数据库升级验证，不能只验证全新数据库。
- UI 结构、核心工作流或视觉语言发生变化时，先走 UI demo gate；仅修正语义、对比度和本地化时可按现有 `RosterTheme` 直接实施。

## 2. 优先级总览

| 编号 | 优先级 | 领域 | 问题 | 关闭所需核心证据 |
| --- | --- | --- | --- | --- |
| 1 | P0 | Contacts | 写回丢失标签和结构化地址 | 映射测试 + 隔离联系人真实写回 |
| 2 | P0 | SQLite | 树形标签与全局唯一约束冲突 | 旧库迁移测试 + 同名分支测试 |
| 3 | P0 | 持久化 | 写入错误被吞掉，内存仍显示成功 | 故障注入测试 + UI 失败状态 |
| 4 | P0 | 构建 | iOS `RosterShared` 无法编译 | iOS Simulator target 构建通过 |
| 5 | P1 | 性能 | 批量写回逐条刷新整本通讯录 | 调用次数测试 + Instruments |
| 6 | P1 | 存储 | 操作历史无界增长并重复保存头像 | 保留策略测试 + 数据库体积检查 |
| 7 | P1 | 并发 | 取消不能中止已开始的派生计算 | 取消测试 + 快速连续输入验证 |
| 8 | P1 | 性能 | 主线程按标签和联系人交叉计数 | 等价性测试 + Main Thread 检查 |
| 9 | P1 | 解析 | 农历中文词条发生重叠匹配 | 冲突短语参数化测试 |
| 10 | P2 | UI | 日历日期按钮嵌套生日按钮 | 鼠标、键盘、VoiceOver 验收 |
| 11 | P2 | UI | 联系人行用手势模拟按钮 | 原生选择语义和键盘验收 |
| 12 | P2 | 无障碍 | 小字号 Pill 文本对比度不足 | 对比度计算 + Accessibility Inspector |
| 13 | P2 | 本地化 | 多处硬编码简体中文及重复本地化源 | 三语言检查 + 源码扫描 |
| 14 | P2 | 体验 | 滚动重置、导航、hover 和朗读信息不完整 | 分项人工验收 |

## 3. P0：数据安全与发布阻断

### 3.1 Contacts 写回丢失标签和结构化地址

**现象与风险**

`ContactsRepository` 读取联系人时把电话、邮箱和地址压平成 `[String]`；写回时重新创建无标签的 `CNLabeledValue`，并把格式化后的地址整体写入 `street`。用户即使只编辑生日、姓名或头像，也可能失去 home/work 标签，以及城市、州、省、邮编、国家等地址组件。

**当前证据**

- `Sources/RosterCore/ContactsRepository.swift:278-287`
- `Sources/RosterCore/ContactsRepository.swift:449-451`
- `Sources/RosterCore/RosterModels.swift:231-233`
- `Sources/RosterShared/RosterAppModel.swift:2116,2188`

**修复边界**

- 模型需要保留每个电话、邮箱的 label，以及 `CNPostalAddress` 的结构化组件。
- 未被用户修改的字段不得重建；只把实际修改的字段写回 Contacts。
- 地址编辑不能依赖换行符区分多条地址。
- 不改变 Contacts 权限申请和用户确认边界。

**自动化验收**

- [ ] 增加电话、邮箱和地址的读取后写回 round-trip 测试。
- [ ] 测试至少覆盖 home/work/custom label、两条电话、两条邮箱和两条结构化地址。
- [ ] 只修改生日时，测试断言上述字段的 label、顺序和结构化组件完全不变。
- [ ] 只修改一条电话或地址时，未修改条目保持不变。
- [ ] 旧缓存中只有 `[String]` 的数据仍可解码，不因模型升级导致启动失败。

**人工验收**

1. 在 macOS Contacts 中创建一个专用测试联系人，填入 home/work 电话、邮箱和两条完整地址。
2. 在 Roster 中只修改生日并确认写回。
3. 回到 Contacts，逐项核对标签、地址组件、顺序和内容。
4. 再分别修改姓名、头像和单条联系方式，确认未修改字段不变。

**完成标准**

- 自动化 round-trip 测试通过。
- 专用测试联系人真实写回通过。
- 评审 diff 时不存在把全部联系方式统一重建为 `label: nil` 的路径。

### 3.2 树形标签与 SQLite 全局唯一约束冲突

**现象与风险**

领域模型允许不同父节点下出现同名标签，SQLite 却使用全局 `UNIQUE(name)` 和 `INSERT OR REPLACE`。创建第二个同名标签时，SQLite 会删除旧标签行；当前连接没有启用 foreign keys，原关联记录成为孤儿，并在重新加载时消失。内存状态与持久化状态也可能不一致。

**当前证据**

- `Sources/RosterShared/RosterAppModel.swift:1109-1119`
- `Sources/RosterShared/RosterAppModel.swift:1163-1168`
- `Sources/RosterShared/Services/ContactTagStore.swift:29-56`
- `Sources/RosterShared/Services/ContactTagStore.swift:254-269`

**修复边界**

- 唯一性改为父节点范围内、大小写不敏感的名称唯一。
- 保存和重命名使用标签 `id` 定位，禁止用 `REPLACE` 删除冲突行。
- 明确根标签的 `NULL parent_tag_id` 唯一性处理。
- 迁移必须保留现有标签 ID、层级、排序和联系人关联。

**自动化验收**

- [ ] 用旧 schema 创建数据库并写入标签和联系人关联，再执行迁移，数据完整保留。
- [ ] `工作/客户` 与 `个人/客户` 可以同时持久化，重启后都存在且关联不串线。
- [ ] 同一父节点下创建 `客户` 与 `客户`，以及 `客户` 与 `客戶`/大小写等约定冲突时，返回明确错误且不覆盖旧数据。
- [ ] 重命名冲突测试断言数据库和内存都保持原值。
- [ ] 删除一个分支的同名标签不会删除另一分支标签或其联系人关联。
- [ ] 测试迁移重复执行，结果保持幂等。

**人工验收**

1. 创建两个父标签，并分别创建同名子标签。
2. 给两个子标签分配不同联系人，退出并重新启动 App。
3. 核对标签树和联系人分配均未变化。
4. 尝试制造同父级名称冲突，确认 UI 显示错误且原标签未消失。

**完成标准**

- 旧库迁移和同名分支测试通过。
- schema 中不存在全局 `UNIQUE(name)`。
- 标签 upsert 不再使用会删除旧行的 `INSERT OR REPLACE`。

### 3.3 持久化失败被静默吞掉

**现象与风险**

操作日志、草稿、标签和部分本地存储会吞掉 prepare、bind、step 或解码错误。调用层继续更新内存并显示成功，用户重启后可能发现数据消失；安全日志读取失败还会表现为“没有待处理操作”。

**当前证据**

- `Sources/RosterShared/Services/ContactOperationJournalStore.swift:233-313`
- `Sources/RosterShared/Services/ContactOperationJournalStore.swift:396,419`
- `Sources/RosterShared/Services/ContactTagStore.swift:29-56`
- `Sources/RosterShared/Services/ContactSnapshotCache.swift:80-96`
- `Sources/RosterShared/Services/LocalRosterStore.swift:43-104`
- `Sources/RosterShared/RosterAppModel.swift:1286-1291,1326-1339`

**修复边界**

- 所有 SQLite prepare、bind、step 和 transaction 结果必须检查。
- 写 API 返回成功或抛出包含 SQLite code/message 的错误。
- 只有持久化成功后才能更新对应内存状态和成功提示。
- 读取失败与“数据库为空”必须是两种状态；不得用空数组掩盖损坏或 I/O 失败。

**自动化验收**

- [ ] 对只读数据库、关闭后的 connection、约束冲突和损坏 payload 做故障注入测试。
- [ ] 每种写失败都向调用层返回错误，内存数组和 selection 不发生乐观提交。
- [ ] journal 读取失败时返回失败状态，而不是空操作列表。
- [ ] transaction 中任一步失败会 rollback，不留下半条操作或孤儿记录。
- [ ] 错误恢复后重试能够成功，且不会重复插入操作。

**人工验收**

1. 使用测试数据库模拟不可写状态。
2. 在 App 中创建标签或保存草稿。
3. 确认 UI 显示可理解的失败信息，不显示成功 Toast，列表不出现未落盘数据。
4. 恢复写权限并重试，确认数据可在重启后保留。

**完成标准**

- 相关 store 不存在无处理的 `catch {}` 和未检查的写入 `sqlite3_step`。
- 故障注入测试覆盖 journal 与 tag store 的主要写路径。
- UI 能区分失败、空数据和加载中状态。

### 3.4 iOS `RosterShared` 无法编译

**现象与风险**

`Package.swift` 声明 iOS 17 和 `RosterIOS` 产品，但共享主题无条件调用 macOS 专属的 `Color(nsColor:)`。这使 iOS target 在编译阶段失败。

**当前证据**

- `Sources/RosterShared/Theme/RosterTheme.swift:69,73,77,81`
- `Package.swift`
- `Sources/RosterIOSApp/RosterIOSApp.swift`

**修复边界**

- 如果 iOS 仍受支持，共享主题必须使用跨平台语义色或做明确的平台条件编译。
- 如果 iOS 已取消，删除 Package 产品、target 和失效源码，避免保留虚假的支持承诺。
- 本项开始实施前必须由产品负责人确认 iOS 是否继续支持。

**自动化验收**

- [ ] macOS `swift build` 和 `swift test` 通过。
- [ ] 以下 iOS Simulator 构建命令通过：

```bash
swift build \
  --scratch-path .build-ios-audit \
  --triple arm64-apple-ios17.0-simulator \
  --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  --target RosterShared
```

- [ ] CI 同时包含 macOS 测试和 iOS target 构建，后续不能静默回归。

**人工验收**

- 在浅色和深色模式下启动 iOS App，核对背景、文本、分隔线和控制背景仍使用预期语义色。

**完成标准**

- iOS 支持决策已记录。
- 保留 iOS 时，CI 的 iOS 构建通过；取消 iOS 时，仓库不再暴露不可用产品。

## 4. P1：性能与正确性

### 4.1 批量写回逐条刷新整本通讯录

**现象与风险**

批量操作逐条调用 `writeBack`，每条成功后执行一次完整 `refreshContacts()`。批量修改 100 位联系人会产生约 100 次 Contacts 全量读取、分组重建和派生数据更新。

**当前证据**

- `Sources/RosterShared/RosterAppModel.swift:1346-1349`
- `Sources/RosterShared/RosterAppModel.swift:1414-1415`
- `Sources/RosterShared/RosterAppModel.swift:1533-1535`
- `Sources/RosterShared/Services/ContactSyncService.swift:35-43`
- `Sources/RosterCore/ContactsRepository.swift:200-227`

**修复边界**

- 单条写回继续在成功后刷新。
- 批量写回期间抑制逐条刷新，全部操作结束后统一刷新一次。
- 部分失败时仍刷新一次，并准确保留每条操作的成功/失败结果。
- 不并发写 Contacts，避免破坏系统存储的写入顺序。

**自动化验收**

- [ ] 给 `ContactSyncService` 或 repository spy 计数：N 条批量写回时 save 调用 N 次，fetch snapshot 调用恰好 1 次。
- [ ] 0 条操作时不刷新；单条独立写回仍刷新 1 次。
- [ ] 中间一条失败时，剩余策略符合产品约定，最终只刷新 1 次，结果统计准确。
- [ ] 批量结束前取消任务时，已完成和未完成操作状态明确且可恢复。

**人工验收**

- 使用测试联系人执行 100 条批量修改，在 Instruments 或 signpost 中确认没有 100 次完整联系人快照。
- 批量完成后列表、标签计数和日历数据一致，无需手动刷新。

**完成标准**

- 调用次数测试通过。
- Instruments 记录中一次批量操作只有一次最终全量刷新。

### 4.2 操作历史无界增长并重复保存头像

**现象与风险**

每条操作历史嵌入完整 `LocalContactDraft`，其中可能包含头像 `imageData`；读取历史时没有 `LIMIT`，也没有清理策略。长期使用会增加数据库体积、启动解码时间和内存占用。

**当前证据**

- `Sources/RosterShared/Services/ContactOperationJournalStore.swift:36-55`
- `Sources/RosterShared/Services/ContactOperationJournalStore.swift:170-180`
- `Sources/RosterShared/Services/ContactOperationJournalStore.swift:333-345`
- `Sources/RosterApp/Views/Contacts/ContactSyncHistoryView.swift:95-96`

**修复边界**

- pending、failed、conflict 操作完整保留，不能因清理历史失去恢复能力。
- applied、reverted 历史设定明确上限；默认建议各状态合计最多保留最近 500 条。
- 历史操作只保存恢复所需字段，不重复保存头像二进制；当前草稿仍可保存头像。
- 清理在事务内完成，并保留稳定排序。

**自动化验收**

- [ ] 写入超过上限的已完成操作后，只保留最近 500 条。
- [ ] pending、failed、conflict 不受已完成历史上限影响。
- [ ] 删除旧历史不会删除当前草稿、策略设置或待处理操作。
- [ ] 新写入的历史 payload 不包含图片字节。
- [ ] 旧数据库中带图片的 payload 仍可读取，并在下一次维护时安全清理。

**人工验收**

- 构造大量历史记录，比较清理前后的数据库大小和同步历史页启动时间。
- 核对 UI 仍显示正确的最近记录和所有未解决操作。

**完成标准**

- 数据库存量有明确上限。
- 启动不再解码无界的已完成历史和重复图片。

### 4.3 取消不能中止已开始的派生计算

**现象与风险**

调用方会取消旧 Task 并用 request ID 阻止旧结果应用，但 actor 内的同步循环没有 cancellation check。旧计算一旦开始仍会占用 actor，新的搜索、筛选或月份请求必须排队等待。

**当前证据**

- `Sources/RosterShared/RosterAppModel.swift:371-388`
- `Sources/RosterShared/RosterAppModel.swift:753-765`
- `Sources/RosterShared/Services/RosterDerivedDataWorker.swift:56-133`
- `Sources/RosterShared/Services/ContactListProjectionService.swift:131-154`

**修复边界**

- 保留现有 debounce 和 request ID 防陈旧结果机制。
- 在顶层阶段和可观的循环批次间执行 `Task.checkCancellation()`。
- 不需要为每个元素检查一次；检查频率应兼顾响应速度和循环开销。

**自动化验收**

- [ ] 启动大数据 projection 后取消，任务以 `CancellationError` 或明确取消结果结束。
- [ ] 取消旧请求后立即提交新请求，新请求不必等待旧请求完整计算结束。
- [ ] 被取消请求不会更新 rows、grouped occurrences、loading 或 selection 状态。
- [ ] 未取消的相同输入仍命中现有缓存。

**人工验收**

- 快速连续输入搜索文本、切换筛选器和月份，确认最终结果始终对应最后一次输入。
- Instruments 中被取消任务的 CPU 区段及时结束，不持续跑完整轮计算。

**完成标准**

- 自动化测试同时证明“旧结果不应用”和“旧计算会提前结束”。

### 4.4 标签计数在主线程做交叉扫描

**现象与风险**

`RosterAppModel` 是 `@MainActor`，重建标签选项时为每个标签扫描所有可见联系人，并计算子树。规模增大后，标签或联系人变化会阻塞主线程。

**当前证据**

- `Sources/RosterShared/RosterAppModel.swift:120`
- `Sources/RosterShared/RosterAppModel.swift:769-775`
- `Sources/RosterShared/RosterAppModel.swift:977-986`
- `Sources/RosterShared/RosterAppModel.swift:1816-1836`

**修复边界**

- 标签计数移入现有 contact projection worker 或一次后台快照计算。
- 一次遍历联系人累计直接标签计数，再按标签树汇总后代计数。
- UI 只读取不可变的计数快照，不在 `body` 或主线程重新扫描。

**自动化验收**

- [ ] 新算法与当前实现对同一 fixture 的计数完全一致。
- [ ] 覆盖父标签、子标签、多标签联系人、未标签联系人、隐藏/不可见联系人和空标签。
- [ ] 同一联系人有多个后代标签时，不因父节点汇总发生重复计数。
- [ ] 性能测试或计数器证明一次重建不会为每个标签重新扫描全部联系人。

**人工验收**

- 使用大联系人/标签 fixture 切换视图和标签，在 Time Profiler 中确认主线程不再出现 `taggedContactCount` 整表扫描。

**完成标准**

- 计数结果与旧实现一致。
- 主线程只应用计数快照，不参与全量聚合。

### 4.5 农历中文词条重叠匹配

**现象与风险**

解析器在包含重叠键的 Dictionary 上调用 `first(where:)` 做子串匹配。Dictionary 遍历顺序不能表达优先级，`十一月`、`十二月初十` 等输入可能把短月份词或月份中的数字误识别为日期。

**当前证据**

- `Sources/RosterCore/DatePhraseParser.swift:63-68`
- `Sources/RosterCore/DatePhraseParser.swift:98-120`
- `Tests/RosterCoreTests/RosterCoreTests.swift:8-15`

**修复边界**

- 先确定月字段边界，再解析日字段。
- 对重叠词条使用确定的最长匹配或精确 token 匹配，不能依赖 Dictionary 顺序。
- 保留闰月和现有简繁体输入能力。

**自动化验收**

- [ ] 参数化覆盖 `十一月初五`、`十一月十一`、`十二月初十`、`十二月十二`。
- [ ] 覆盖 `正月`、`冬月`、`腊月`、`闰六月初五` 等现有别名。
- [ ] 同一测试重复运行结果稳定，不受 hash seed 或构建配置影响。
- [ ] 非法日期返回失败，不自动截断或改成另一个有效日期。

**人工验收**

- 在编辑器中逐个输入上述短语，核对解析预览和最终保存的农历月、日、闰月标记。

**完成标准**

- 冲突短语测试全部通过。
- 解析代码不存在无序容器上的模糊 `first(where:)`。

## 5. P2：UI、无障碍与本地化

### 5.1 日历日期按钮嵌套生日按钮

**现象与风险**

`CalendarDayCell` 本身是按钮，内部的 `RosterPill` 又是按钮。嵌套交互控件会造成点击目标、焦点顺序和 VoiceOver 动作语义不稳定。

**当前证据**

- `Sources/RosterApp/Views/Calendar/CalendarViews.swift:96-107`
- `Sources/RosterApp/Views/Calendar/CalendarViews.swift:159`

**修复边界**

- 日期选择和生日详情保留两个独立动作，但不能形成嵌套 Button。
- 整个日期格尺寸不得因拆分交互层而跳动。
- 保持 macOS 原生 focus ring、右键菜单和 hover 反馈。

**自动化验收**

- [ ] 视图结构测试或可测试组件层次中不存在 Button 包含 Button。
- [ ] 日期动作与生日详情动作分别触发一次，不互相冒泡或重复执行。

**人工验收**

- 鼠标点击日期空白、点击生日 Pill、Tab/Shift-Tab、Space/Return 分别验证动作。
- VoiceOver 能按稳定顺序识别日期和每条生日，并分别执行动作。

**完成标准**

- 无嵌套交互控件。
- 鼠标、键盘和 VoiceOver 三条路径均可完成两个动作。

### 5.2 联系人行用手势模拟按钮

**现象与风险**

`ContactListRow` 使用 `onTapGesture` 和手工 accessibility action 模拟选择。相比 `Button` 或 `List(selection:)`，键盘选择、焦点、按压反馈和辅助功能语义不完整。

**当前证据**

- `Sources/RosterApp/Views/Contacts/ContactsEditorView.swift:452-525`

**修复边界**

- 使用原生 `Button`、`List(selection:)` 或与当前多选模型兼容的原生选择机制。
- 保留 Command 多选、Shift 范围选择、拖拽和上下文菜单。
- 行高和列表宽度保持稳定。

**自动化验收**

- [ ] 单击、Command 多选、Shift 范围选择的模型测试通过。
- [ ] 拖拽 payload 和右键菜单测试继续通过。
- [ ] 选中状态具有 `.isSelected` 语义。

**人工验收**

- 不使用鼠标，仅用 Tab、方向键、Space/Return 完成定位和选择。
- VoiceOver 正确朗读联系人名称和选中状态。

**完成标准**

- 主要选择行为不再依赖 `onTapGesture`。
- 原有多选和拖拽能力无回归。

### 5.3 小字号 Pill 文本对比度不足

**现象与风险**

生日 Pill 使用 10pt 白色文字。当前主题下蓝、红、绿背景约为 4.02:1、3.55:1、2.22:1，低于普通文本 4.5:1 的目标；绿色最严重。

**当前证据**

- `Sources/RosterApp/Views/Calendar/CalendarViews.swift:163-169`
- `Sources/RosterShared/Theme/RosterTheme.swift:9-12`

**修复边界**

- 优先调整前景色或语义色明度，不为单个页面复制颜色常量。
- 浅色和深色模式都要满足对比度，并保留不同历法的可辨识性。
- 不通过进一步减小字号解决空间问题。

**自动化验收**

- [ ] 对所有 Pill 前景/背景组合计算 WCAG 对比度，普通文本至少为 4.5:1。
- [ ] 颜色测试覆盖浅色、深色及高对比度环境下使用的实际值。

**人工验收**

- 使用 Accessibility Inspector 检查日历中四种历法 Pill。
- 在浅色、深色、提高对比度设置下确认文字清晰且颜色类别仍可区分。

**完成标准**

- 所有小字号 Pill 达到 4.5:1。
- 没有引入页面私有的重复颜色定义。

### 5.4 硬编码简体中文和重复本地化源

**现象与风险**

同步历史页、批量编辑、侧栏和工具栏存在硬编码简体中文。用户切换到繁体中文或英文时会出现混合语言。`RosterApp` 还保留一份与 Shared 本地化重复的源码，容易造成 key 漂移。

**当前证据**

- `Sources/RosterApp/Views/Contacts/ContactSyncHistoryView.swift:14-76`
- `Sources/RosterApp/Views/Contacts/ContactsEditorView.swift:735-775`
- `Sources/RosterApp/Views/Sidebar/SidebarView.swift:71`
- `Sources/RosterApp/RosterRootView.swift:164,205`
- `Sources/RosterApp/RosterLocalization.swift`
- `Sources/RosterShared/RosterLocalization.swift:197-202`

**修复边界**

- 所有可见文案统一走 Shared `RosterLocalization`。
- 删除或停止编译 App 层重复本地化定义，只保留一个事实来源。
- 中文、繁体中文、英文都提供真实翻译，不以 key 或简体中文回退冒充完成。
- 动态数量和错误信息也必须本地化。

**自动化验收**

- [ ] 本地化 key 在三种语言下都返回非空文本，且不等于 key 名。
- [ ] 同步页和批量编辑页所需 key 有覆盖测试。
- [ ] 源码扫描确认上述视图不存在新的用户可见硬编码中文。
- [ ] Package 中只编译一个 `RosterLocalization` 定义。

**人工验收**

- 分别使用简体中文、繁体中文和英文启动 App，完整走一遍联系人列表、批量编辑、同步历史、侧栏和工具栏。
- 检查截断、混合语言、复数/数量表达和错误提示。

**完成标准**

- 三种语言下相关页面没有混合语言。
- 重复本地化源被移除，现有 key 使用方全部可编译。

### 5.5 次级交互一致性

**现象与风险**

列表筛选通过改变视图 identity 重建列表，可能重置滚动位置；日历缺少方向键网格导航；部分侧栏和日期单元缺少 hover；日期辅助功能标签只朗读裸数字；页面切换还保留整页动画，与高频生产力工具的即时切换目标不一致。

**当前证据**

- `Sources/RosterApp/Views/List/RosterRecordsView.swift:54`
- `Sources/RosterApp/Views/Calendar/CalendarViews.swift:96-150`
- `Sources/RosterApp/Views/Sidebar/SidebarView.swift`
- `Sources/RosterApp/RosterRootView.swift`

**修复边界**

- 移除仅为强制刷新而设置的 `.id(filterSignature)`，由数据状态驱动内容更新。
- 日历实现符合 macOS 预期的方向键移动和焦点可见性。
- hover 只用于可交互元素，不增加装饰性动画。
- 辅助功能标签包含日期、生日数量和必要状态。
- 移除整页切换动画；局部状态反馈动画可继续保留。

**自动化验收**

- [ ] 筛选变化不会重建无关列表容器，选择状态和滚动锚点策略有测试。
- [ ] 日期标签按 0、1、多个生日分别生成自然语言文本。
- [ ] 日历方向键移动不会越界，并能跨周移动。

**人工验收**

- 滚动到列表中部后切换排序和可组合筛选，按产品约定确认保持位置或移动到明确的新锚点，不出现无理由跳顶。
- 用方向键遍历日历，焦点环始终可见，跨月行为一致。
- 鼠标经过侧栏项、日期格和生日项时，交互目标有统一且克制的反馈。
- VoiceOver 朗读“8 月 31 日，2 个生日”等完整语义，不只朗读数字。
- 快速切换侧栏页面，内容立即切换且没有整页位移动画。

**完成标准**

- 五项人工验收全部记录结果。
- 不以额外动画掩盖刷新或 identity 问题。

## 6. 统一回归矩阵

### 6.1 每个改动批次必须执行

```bash
swift test --scratch-path "$PWD/.build"
swift build --scratch-path "$PWD/.build"
scripts/update-local-package.sh
```

验收要求：命令退出码均为 0，Swift Testing 输出 0 failure，本地 `/Applications/Bearoster.app` 可启动。

### 6.2 涉及 iOS 或 Shared 主题时追加

```bash
swift build \
  --scratch-path .build-ios-audit \
  --triple arm64-apple-ios17.0-simulator \
  --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  --target RosterShared
```

### 6.3 涉及 Contacts、SQLite 或真实 App 行为时追加

- 使用隔离的测试联系人和测试数据库，不修改用户已有联系人。
- 运行对应 `RosterAppTests` focused tests。
- 从旧数据库副本启动，验证迁移、重启后数据和失败恢复。
- 通过本地发布版 `.app` 验证权限、确认弹窗、写回和同步历史。

### 6.4 涉及拖拽时追加

按 `docs/e2e/macos-drag-and-drop.md` 执行对应 macOS e2e，不用单元测试替代真实拖拽。

### 6.5 涉及性能时追加

- 保存改动前后的同一 fixture、同一机器和同一操作路径。
- 优先记录全量 Contacts fetch 次数、主线程栈和取消延迟，不只比较主观体感。
- Instruments 证据中不得出现本问题对应的重复全量扫描或刷新。

### 6.6 涉及 UI 时追加

- 浅色、深色、提高对比度。
- 简体中文、繁体中文、英文。
- 鼠标、纯键盘、VoiceOver。
- 窗口最小支持尺寸和常用桌面尺寸。
- 检查文字截断、控件重叠、焦点环、滚动位置和点击目标。

## 7. 建议实施顺序

1. Contacts 结构化写回与 round-trip 测试。
2. 标签 schema 迁移、冲突处理和持久化错误传播。
3. iOS 支持决策及 Shared 构建修复。
4. 批量写回单次刷新和 journal 保留策略。
5. 农历解析确定性修复。
6. 派生任务取消和标签计数性能优化。
7. 日历/联系人交互语义、对比度和本地化。
8. 次级滚动、导航、hover 和朗读体验。

P0 中第 1、2、3 项每项应单独提交和评审，避免 Contacts 数据迁移、标签 schema 与错误处理在同一 diff 中相互遮蔽。

## 8. 已确认完成、不纳入本轮的问题

以下旧审计项已在当前代码中落地，不应重复立项，除非新的性能数据证明回归：

- DateFormatter 缓存。
- 标签树缓存。
- 列表行显示字段预计算。
- 头像渐变。
- 卡片双层阴影清理。
- 刷新加载状态和缩短的进度层。
- 联系人 projection 缓存和 stale request ID 保护。

## 9. 问题关闭记录模板

```markdown
### 问题 #<编号> 关闭记录

- 修改文件：
- 自动化测试：
- 命令与结果：
- 人工验收环境：
- 截图 / Instruments / 数据库证据：
- 迁移与回滚检查：
- 未验证项：无 / <明确列出>
- 评审人：
- 关闭日期：
```

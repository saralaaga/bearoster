# 性能审查：视图 / 标签切换卡顿

> 范围：应用启动后切换侧边栏视图（日历 / 列表 / 联系人 / 标签）、切换标签筛选时的卡顿。
> 结论：数据计算本身已挪到后台 actor（`RosterDerivedDataWorker` / `ContactListProjectionWorker`），
> 剩余卡顿主要来自**主线程每帧的同步开销**与**启动期的重复整表重算**。

## 背景：当前架构（已经做对的部分）

- 派生数据（列表、月视图、即将到来）在 `RosterDerivedDataWorker` 这个 actor 里算，带缓存。
- 联系人 / 标签列表投影在 `ContactListProjectionWorker` actor 里算，行模型 `ContactListRowModel` 预计算好 `daysUntilText / nextRosterText / sortKey` 等。
- `RosterAppModel` 是 `@MainActor @Observable`，视图通过 `@Environment` 订阅。

所以下面的问题**不是**“把计算放后台”这类大改，而是渲染路径上遗留的同步热点。

---

## 问题清单（按收益从高到低）

### P1 — 侧边栏每次切换都做 O(标签数 × 联系人数) 的重算 【高】

**现象**：`selection` 一变，整个 `SidebarView.body` 重新求值（body 里读了 `model.selection` 判断每项 `isSelected`）。body 内每个标签徽标都现算计数。

**位置**
- `Sources/RosterApp/Views/Sidebar/SidebarView.swift:62` — `badge: model.contactCount(for: .untagged)`
- `Sources/RosterApp/Views/Sidebar/SidebarView.swift:303` — 每个 `SidebarTagNodeItem` 的 `badge: model.contactCount(for: .tag(tag.id))`
- `Sources/RosterApp/RosterAppModel.swift:840` — `contactCount(for:)`

```swift
func contactCount(for filter: ContactTagFilter) -> Int {
    let visibleContactIDs = Set(profiles.map(\.id))            // 每次全量重建 Set
    let matchingTagIDs = filter.matchingTagIDs(in: contactTags) // 每次 new ContactTagTree(tags:)
    return visibleContactIDs.filter { ... }.count              // 每次全量扫描
}
```

**根因**：`contactCount` 每次全量重建集合 + 全量扫描；`matchingTagIDs(in:)` 内部又 `ContactTagTree(tags:)` 重建整棵树（`Services/ContactTagFiltering.swift:38`）。同一批调用还包括 `childTags(of:)`、`tagPath(for:)`、`contactTagTreeNodes`、`tagAndDescendantIDs`，**每个都当场 new 一棵树**（`RosterAppModel.swift:824-838`）。

**成本**：N 个联系人、M 个标签，每次切 tab ≈ M 次「建树 + 扫 N」。联系人一多就掉帧。

**怎么改**
1. 把 `ContactTagTree` 缓存为 `RosterAppModel` 的私有属性，仅在 `contactTags` 变化时重建；`childTags / tagPath / tagAndDescendantIDs / contactTagTreeNodes` 全部走这个缓存实例，不再当场 new。
2. 标签计数改为查预计算快照：`tagFilterOptions`（`RosterAppModel.swift:1599`）里其实已经算好了每个 filter 的 `count`。侧边栏徽标直接查 `contactTagFilterOptions`（或新增一份 `tagCountsByID: [String: Int]` 快照），不要每帧现算。

**验收**：切换视图时不再触发 `contactCount` 全量扫描；`ContactTagTree` 每次 `contactTags` 变更只构建一次。

---

### P2 — 列表页（list tab）每行在主线程现算，未走预计算行模型 【高】

**现象**：Contacts / Tags 页用后台预计算的 `ContactListRowModel`，但 list tab 没有，每行现算。

**位置**：`Sources/RosterApp/Views/List/RosterRecordsView.swift:36-51`

```swift
ForEach(group.occurrences) { occurrence in
    let daysUntil = model.resolver.daysUntil(occurrence.date)   // 引擎调用
    RosterOccurrenceListRow(
        tags: model.tags(for: occurrence.record.contactID),     // O(标签数) + 排序，逐行
        kindTitle: shortKindName(occurrence.record.kind, model: model),
        metaText: metaText(for: occurrence, locale: locale),    // 内含新建 DateFormatter（见 P3）
        isToday: Calendar.current.isDateInToday(occurrence.date),
        ...
    )
}
```

`model.tags(for:)`（`RosterAppModel.swift:817`）逐行过滤 + 排序整个 `contactTags`。`LazyVStack` 只渲染可见行，但滚动 / 切换时这些开销叠加 P3 的 formatter 一起就卡。

**怎么改**：在 `RosterDerivedDataSnapshot`（`Services/RosterDerivedDataWorker.swift:33`）的 occurrence / group 数据里预计算 `daysUntil / daysUntilText / metaText / kindTitle / tags / isToday`，与 contacts 那套对齐。视图只做展示。

**验收**：`RosterRecordsView` 行内不再调用 `resolver` / `model.tags(for:)` / `DateFormatter`。

**风险**：需改 `RosterDerivedDataSnapshot` 结构，动到多个文件，建议单独一轮并补测试。

---

### P3 — `occurrenceDate` 每次新建 `DateFormatter` 【高】

**现象**：`DateFormatter()` 初始化很贵（解析 locale / 日历 / 模板），却在渲染热路径上高频新建。

**位置**
- `Sources/RosterCore/CalendarFormattingService.swift:46` — `occurrenceDate` 每次 `let formatter = DateFormatter()`
- 同文件 `monthTitle:320`、`weekdaySymbols:314`
- `Sources/RosterApp/Views/Calendar/CalendarViews.swift:144` — `CalendarDayCell.accessibilityLabel` **每格新建一个**，月视图 42 格 = 42 个 formatter
- 同文件 `dayTitle:225`、`daySubtitle:238`、`monthSymbol:378`
- 调用方：`RosterRecordsView.metaText`、`RosterOccurrenceCard`、`DayOccurrenceCard`、`NextRosterCard` 每张卡各一次

**怎么改**：在 `CalendarFormattingService` 内按 locale 缓存 `DateFormatter`（`[AppLocale: DateFormatter]`，或静态 `nonisolated(unsafe)` 缓存 + 复用）。视图层的 `DateFormatter` 也改为调用 service 的缓存方法，不在 `body` / `accessibilityLabel` 里新建。

**验收**：渲染一屏列表 / 月视图时 `DateFormatter` 实例数为常量级，不随行数 / 天数增长。

**风险**：最低。建议**优先做这一项**。

---

### P4 — 排序比较器内反复跑 `CFStringTransform` 【中，影响首次 / 大数据计算时长】

**现象**：`NameSortKey.romanized`（`Services/NameSortKey.swift:4`）用 `CFStringTransform` 转拉丁 + 去音标，不便宜；却在比较器内部对两侧各算一次。

**位置**
- `Sources/RosterCore/RosterDerivedDataService.swift:185` — `compareByName` 内两侧各 `romanized` 一次 → 排序 O(n log n) 次比较 = romanize 被算 O(n log n) 遍
- `Sources/RosterApp/Services/ContactListProjectionService.swift:169` — 已预存 `sortKey`，但比较时 `NameSortKey.sectionSortValue(lhs.sectionKey)` 仍每次现算

**怎么改**：decorate–sort–undecorate。先给每个元素算一次 `romanized` / `sectionSortValue` 存起来，再排序比较用缓存值。

**验收**：一次排序中每元素的 `romanized` 只计算一次。

**位置提示**：在后台 actor 内，不影响帧率，但拖长首次计算（即启动慢的一部分）。

---

### P5 — 启动期 `dataGeneration` 连环递增，派生缓存反复整表作废 【中】

**现象**：启动那几秒派生数据从零算多遍。

**位置 / 触发链**
- `RosterAppModel.swift:214`（`init` 一次 `scheduleDerivedDataRebuild`）
- `RosterAppModel.swift:219-222`：并发的 `loadLocalRosterSpecs` / `loadContactTags` / `loadContactJournal` / `loadCachedContactSnapshot` 各自再触发一轮 `rebuildContactProjection` + `scheduleDerivedDataRebuild`
- `RosterApp.swift:27`：`applicationDidFinishLaunching` 又 `refreshContacts()` → `applyContactSnapshot` → `dataGeneration += 1`
- `Services/RosterDerivedDataWorker.swift:139`：缓存 key 含 `generation`，每次 `dataGeneration += 1` 让**整份派生缓存失效**

而 `visibleMonthData` 对当月 42 格逐日 `resolver.occurrences(on:)`，每格 O(records)（`RosterDerivedDataService.swift:245`），重复算几遍成本可观。

**怎么改**：合并启动期触发——本地存储 load 全部完成后统一算一次；或对同一批数据的重算做去抖（coalesce），避免 generation 连续跳变清空缓存。

**验收**：冷启动到首屏可交互期间，`RosterDerivedDataWorker.snapshot` 的“未命中缓存全量计算”次数明显下降（理想 1~2 次）。

---

### P6 — `Calendar.current` 在热循环里反复取 【中低】

**现象**：`Calendar.current` 是计算属性，每次访问都读用户设置并构造实例。

**位置**：`CalendarDayCell`（每格多次：`component` / `isDateInToday` / `isDate(inSameDayAs:)`，`CalendarViews.swift:78,90,97,...`）、各比较器、`daysUntil`。

**怎么改**：service / engine 内持有一个 `Calendar` 实例复用（引擎已有 `gregorianCalendar`）；视图层用共享常量或注入，避免每格反复取 `.current`。

**验收**：热路径不再出现裸 `Calendar.current`。

---

### P7 — `TagDropRail` / `GroupDropRail` 每次重绘重建标签树 【低，随 P1 一起解决】

**位置**：`Sources/RosterApp/Views/Contacts/ContactsEditorView.swift:108` — `model.contactTagTreeNodes` 每次 new `ContactTagTree`。

**怎么改**：与 P1 的 `ContactTagTree` 缓存同根因，修了 P1 自动受益。

---

### P8 — 进度覆盖层最小显示 0.45s，放大“慢”的观感 【体验，非真卡】

**位置**：`RosterAppModel.swift:326` `finishCalculationProgress`，`minimumVisibleSeconds = 0.45`。

**现象**：启动期多轮重算（见 P5）× 每轮至少 0.45s，进度条反复闪现，主观像“卡了一下”。

**怎么改**：P5 修好后重算次数下降，此项自然缓解；也可把最小显示时间下调，或仅在“预计算耗时超过阈值（如 150ms）”时才显示进度层，短任务直接跳过。

---

## 建议的落地顺序

| 批次 | 项目 | 风险 | 说明 |
|------|------|------|------|
| 第 1 批（低风险，先做） | P3 缓存 DateFormatter、P1 缓存 ContactTagTree + 计数查表、P7、P6 | 低 | 只改内部实现，不动数据结构；收益立竿见影 |
| 第 2 批 | P4 decorate-sort、P5 合并启动重算 | 中 | 后台逻辑，需回归排序结果与启动行为 |
| 第 3 批 | P2 list tab 走预计算行模型 | 中 | 改 `RosterDerivedDataSnapshot` 结构，需补测试 |
| 收尾 | P8 进度层策略 | 低 | 依赖 P5 效果再定阈值 |

## 验证

每批改完执行：

```bash
swift build
swift test
```

排序 / 计数相关（P1、P2、P4）需确认现有测试覆盖，必要时补：
- 标签计数与 `tagFilterOptions` 一致
- 排序结果在改为 decorate-sort 前后完全一致（含中英文混排、去音标）
- list tab 行内容与 occurrence 数据一致

## 备注

以上均为渲染 / 计算路径优化，不改变功能与 UI 呈现。若要量化收益，建议在 `RosterDerivedDataWorker.snapshot` 和 `contactCount` 处临时加计时日志（或用 Instruments 的 Time Profiler / SwiftUI 模板），对比改动前后的主线程占用与冷启动到首屏时间。

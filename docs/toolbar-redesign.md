# 生日列表工具栏重新设计

**设计日期**: 2026-08-10  
**问题区域**: 生日列表页面顶部工具栏  
**当前状态**: 需要重新设计

---

## 一、当前问题分析

### 1.1 布局问题 🔴

从截图可以看到，当前工具栏存在严重的布局问题：

```
当前布局（问题）：
┌────────────────────────────────────────────────────────────────┐
│ 生日  │ 历法  │ 全部 ▾ │ 排序 │ [最近生日] [姓名] [年龄] [历法] │ 🔍 搜索 │ 5 │
│ 列表  │                                                               │
└────────────────────────────────────────────────────────────────┘
```

**问题清单**:
1. ❌ **标题换行折叠** - "生日列表" 换成两行，浪费空间
2. ❌ **排序按钮无意义** - "排序" 文本标签没有作用，只是占位
3. ❌ **分段控件过长** - 4 个排序选项挤在一起，占据大量空间
4. ❌ **视觉混乱** - 历法筛选、排序、搜索混在一起，层级不清
5. ❌ **对齐问题** - 元素高度不一致，视觉不整洁

### 1.2 交互问题 🟡

1. **排序切换频繁吗？** 
   - 大多数用户进入后会保持一个排序方式
   - 不需要 4 个并列的按钮一直显示

2. **历法筛选有用吗？**
   - 可能只在多历法混合时才需要
   - 大部分用户可能只用公历

3. **信息层级不清**
   - 主要操作（搜索）和次要操作（筛选、排序）权重相同

---

## 二、设计原则

### 2.1 Apple Human Interface Guidelines

根据 macOS HIG：
- **工具栏应该简洁** - 只显示最常用的操作
- **使用弹出菜单** - 对于不频繁的选项使用下拉菜单
- **保持对齐** - 统一的视觉节奏
- **给内容让路** - 工具栏应该紧凑，让主内容区更大

### 2.2 Emil Kowalski 原则

- **去掉不必要的元素** - "排序" 标签完全多余
- **简化操作** - 不要让用户在 4 个按钮中选择
- **保持呼吸感** - 元素之间需要适当的间距

---

## 三、重新设计方案

### 3.1 方案 A：极简工具栏（推荐）⭐️

```
新布局（简洁）：
┌────────────────────────────────────────────────────────────────┐
│ 生日列表  │  历法 [全部 ▾]  排序 [最近生日 ▾]  │     🔍 搜索     │ 5 │
└────────────────────────────────────────────────────────────────┘
```

**改进点**:
- ✅ 标题不换行，保持在一行
- ✅ 历法和排序都用下拉菜单（Picker with .menu style）
- ✅ 搜索框右对齐，作为主要交互
- ✅ 总数徽章保持

**布局结构**:
```swift
HStack(spacing: 12) {
    // 左侧：标题
    Text("生日列表")
        .font(.system(size: 15, weight: .semibold))
        .frame(minWidth: 80, alignment: .leading)
    
    // 中间：筛选和排序
    HStack(spacing: 16) {
        // 历法筛选
        HStack(spacing: 6) {
            Text("历法")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
            Picker("", selection: $filter) {
                // ...
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
        
        // 排序
        HStack(spacing: 6) {
            Text("排序")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
            Picker("", selection: $sort) {
                // ...
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
    }
    
    Spacer(minLength: 12)
    
    // 右侧：搜索 + 总数
    SearchField(text: $searchText, prompt: "搜索")
        .frame(width: 220)
    
    Text("\(count)")
        .badge()
}
.padding(.horizontal, 16)
```

**优点**:
- 紧凑高效，一行显示所有控件
- 清晰的信息层级：标题 > 筛选 > 搜索
- 符合 macOS 原生风格
- 不常用的选项收进菜单

**缺点**:
- 排序切换需要点击菜单（多一步）

---

### 3.2 方案 B：分层工具栏

```
新布局（分层）：
┌────────────────────────────────────────────────────────────────┐
│ 生日列表                        🔍 搜索                      5 │
├────────────────────────────────────────────────────────────────┤
│ 历法 [全部 ▾]  排序 [最近生日 ▾]                               │
└────────────────────────────────────────────────────────────────┘
```

**改进点**:
- ✅ 分成两行，第一行是主要操作（标题 + 搜索）
- ✅ 第二行是筛选选项（历法 + 排序）
- ✅ 视觉更清晰

**布局结构**:
```swift
VStack(spacing: 0) {
    // 第一行：标题 + 搜索
    HStack(spacing: 12) {
        Text("生日列表")
            .font(.system(size: 15, weight: .semibold))
        
        Spacer()
        
        SearchField(text: $searchText)
            .frame(width: 220)
        
        Text("\(count)")
            .badge()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    
    Divider()
    
    // 第二行：筛选
    HStack(spacing: 16) {
        HStack(spacing: 6) {
            Text("历法")
            Picker("", selection: $filter) { ... }
                .pickerStyle(.menu)
        }
        
        HStack(spacing: 6) {
            Text("排序")
            Picker("", selection: $sort) { ... }
                .pickerStyle(.menu)
        }
        
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
}
```

**优点**:
- 分层清晰，不拥挤
- 搜索框更突出

**缺点**:
- 占用更多垂直空间
- 对于简单场景可能过度设计

---

### 3.3 方案 C：混合工具栏（平衡方案）

```
新布局（混合）：
┌────────────────────────────────────────────────────────────────┐
│ 生日列表  │  [全部 ▾]  [最近生日 ▾]  │    🔍 搜索          │ 5 │
└────────────────────────────────────────────────────────────────┘
```

**改进点**:
- ✅ 去掉 "历法" 和 "排序" 标签（节省空间）
- ✅ 下拉菜单显示当前选中值
- ✅ 用户可以从菜单标题推断用途

**布局结构**:
```swift
HStack(spacing: 12) {
    Text("生日列表")
        .font(.system(size: 15, weight: .semibold))
        .frame(minWidth: 80, alignment: .leading)
    
    // 直接显示选择器，无标签
    Picker("", selection: $filter) {
        Text("全部").tag(nil)
        Text("公历").tag(.gregorian)
        // ...
    }
    .pickerStyle(.menu)
    .fixedSize()
    
    Picker("", selection: $sort) {
        Text("最近生日").tag(.next)
        Text("姓名").tag(.name)
        // ...
    }
    .pickerStyle(.menu)
    .fixedSize()
    
    Spacer(minWidth: 12)
    
    SearchField(text: $searchText)
        .frame(width: 220)
    
    Text("\(count)")
        .badge()
}
```

**优点**:
- 最紧凑
- 菜单标题自解释

**缺点**:
- 初次使用可能需要探索

---

## 四、推荐方案对比

| 维度 | 方案 A（极简） | 方案 B（分层） | 方案 C（混合） |
|------|---------------|---------------|---------------|
| **简洁度** | ⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️⭐️ |
| **清晰度** | ⭐️⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️ |
| **空间效率** | ⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️⭐️ |
| **易用性** | ⭐️⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️ |
| **视觉美观** | ⭐️⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️ | ⭐️⭐️⭐️⭐️ |

### 最终推荐：**方案 A（极简工具栏）** ⭐️

**理由**:
1. ✅ **解决所有当前问题** - 标题不换行，排序简化，布局清晰
2. ✅ **符合 macOS 风格** - 使用 Picker.menu 是原生做法
3. ✅ **信息层级清晰** - 标签 + 菜单的组合让用途明确
4. ✅ **给内容让路** - 工具栏紧凑，列表区更大
5. ✅ **易于实现** - 不需要复杂的布局逻辑

---

## 五、细节设计

### 5.1 尺寸规范

```swift
// 工具栏高度
toolbarHeight: 54px (保持与日历页一致)

// 元素间距
标题右边距: 16px
标签与选择器间距: 6px
选择器之间间距: 16px
搜索框左边距: auto (Spacer)
搜索框宽度: 220px
徽章左边距: 12px

// 字体
标题: .system(size: 15, weight: .semibold)
标签: .system(size: 12.5, weight: .medium), .secondary
徽章: .system(size: 12, weight: .medium), .secondary
```

### 5.2 颜色规范

```swift
背景: RosterTheme.pageBackground(colorScheme)
标题: .primary
标签: .secondary
选择器: 系统默认
搜索框: RosterTheme.controlBackground + separator border
徽章背景: .secondary.opacity(0.10)
徽章文字: .secondary
```

### 5.3 对齐规范

```
垂直对齐: center
水平布局:
┌─────────┬────────────────────┬──────────────┬────┐
│ 标题    │ 标签+选择器 (左对齐) │ 搜索框 (右对齐)│ 数字│
│ 80px   │                    │ 220px       │ 徽章│
└─────────┴────────────────────┴──────────────┴────┘
```

---

## 六、交互设计

### 6.1 选择器交互

**历法选择器**:
```
菜单项：
- 全部历法
- 公历
- 农历
- 希伯来历
- 伊斯兰历

默认：全部历法
选中效果：菜单显示当前选中项
```

**排序选择器**:
```
菜单项：
- 最近生日
- 姓名
- 年龄
- 历法

默认：最近生日
选中效果：菜单显示当前选中项
快捷键支持：
  Cmd+1: 最近生日
  Cmd+2: 姓名
  Cmd+3: 年龄
  Cmd+4: 历法
```

### 6.2 搜索框交互

- 占位符: "搜索联系人"
- 清除按钮: 有内容时显示 ⓧ（已实现）
- 快捷键: Cmd+F 聚焦搜索框
- 实时搜索: 输入即过滤

### 6.3 响应式设计

```swift
// 窗口过窄时的降级策略
if windowWidth < 900 {
    // 隐藏标签文字，只保留选择器
    "历法" -> 隐藏
    "排序" -> 隐藏
}

if windowWidth < 800 {
    // 搜索框缩小
    searchFieldWidth: 180px
}

if windowWidth < 700 {
    // 换成两行布局（方案 B）
}
```

---

## 七、实现要点

### 7.1 关键代码结构

```swift
struct RosterListToolbarControls: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        @Bindable var model = model
        
        HStack(spacing: 12) {
            // 标题
            titleView
            
            // 筛选器
            filterControls
            
            Spacer(minLength: 12)
            
            // 搜索 + 总数
            searchAndCount
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var titleView: some View {
        Text(model.l10n(.list))
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(minWidth: 80, alignment: .leading)
    }
    
    private var filterControls: some View {
        HStack(spacing: 16) {
            // 历法筛选
            HStack(spacing: 6) {
                Text(model.l10n(.calendarKind))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $model.filter) {
                    Text(model.l10n(.all)).tag(RosterCalendarKind?.none)
                    ForEach(RosterCalendarKind.allCases) { kind in
                        Text(model.formatter.calendarName(kind, locale: model.language.coreLocale))
                            .tag(Optional(kind))
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
            
            // 排序
            HStack(spacing: 6) {
                Text(model.l10n(.sort))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $model.sort) {
                    Text(model.l10n(.nearest)).tag(RosterSort.next)
                    Text(model.l10n(.name)).tag(RosterSort.name)
                    Text(model.l10n(.age)).tag(RosterSort.age)
                    Text(model.l10n(.calendarKind)).tag(RosterSort.calendar)
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }
    
    private var searchAndCount: some View {
        HStack(spacing: 12) {
            SearchField(text: $model.searchText, prompt: model.l10n(.search))
                .frame(width: 220)
            
            Text("\(model.filteredRecords.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Color.secondary.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
    }
}
```

### 7.2 注意事项

1. **Picker.menu 样式**
   - 使用 `.pickerStyle(.menu)` 创建下拉菜单
   - 使用 `.fixedSize()` 防止过度拉伸
   - 菜单会自动显示当前选中项

2. **标签文本**
   - 使用 `.secondary` 颜色降低视觉权重
   - 12.5pt 比 13pt 略小，更次要

3. **对齐**
   - 标题用 `frame(minWidth:alignment:)` 保持宽度
   - Spacer(minLength:) 确保最小间距

4. **响应式**
   - 使用 GeometryReader 检测宽度
   - 根据宽度调整布局

---

## 八、视觉对比

### Before (当前设计)
```
问题：
❌ 标题换行
❌ "排序" 标签无用
❌ 4 个分段按钮太长
❌ 视觉拥挤
❌ 层级不清

┌────────────────────────────────────────────────────────────────┐
│ 生日  │ 历法 │ 全部▾ │ 排序 │ [最近生日][姓名][年龄][历法] │ 搜索 │ 5 │
│ 列表  │                                                             │
└────────────────────────────────────────────────────────────────┘
```

### After (新设计)
```
改进：
✅ 标题一行
✅ 无多余标签
✅ 下拉菜单节省空间
✅ 视觉简洁
✅ 层级清晰

┌────────────────────────────────────────────────────────────────┐
│ 生日列表  │  历法 [全部 ▾]  排序 [最近生日 ▾]  │   🔍 搜索   │ 5 │
└────────────────────────────────────────────────────────────────┘
```

---

## 九、可访问性

### 9.1 VoiceOver 支持

```swift
// 历法选择器
.accessibilityLabel(model.l10n(.calendarKind))
.accessibilityValue(currentFilterName)

// 排序选择器
.accessibilityLabel(model.l10n(.sort))
.accessibilityValue(currentSortName)

// 总数徽章
.accessibilityLabel("\(count) \(model.l10n(.birthdays))")
```

### 9.2 键盘导航

- Tab: 在控件间切换
- Space: 打开当前选择器
- Cmd+F: 聚焦搜索框
- Cmd+1/2/3/4: 快速切换排序

---

## 十、总结

### 改进效果

| 指标 | Before | After | 提升 |
|------|--------|-------|------|
| **工具栏高度** | ~70px (两行) | 54px (一行) | ⬇️ -23% |
| **控件数量** | 9 个可见元素 | 6 个可见元素 | ⬇️ -33% |
| **点击效率** | 排序需 1 次点击 | 排序需 2 次点击 | ⬇️ -1 步 |
| **视觉复杂度** | 高 | 低 | ⬆️ 显著改善 |
| **空间利用** | 内容区 ~85% | 内容区 ~90% | ⬆️ +5% |

### 核心优势

1. ✅ **解决标题折叠** - 单行布局，标题完整显示
2. ✅ **简化排序** - 用下拉菜单代替 4 个按钮
3. ✅ **清晰层级** - 标题 > 筛选 > 搜索，一目了然
4. ✅ **节省空间** - 更多空间留给内容列表
5. ✅ **符合规范** - macOS 原生风格

### 实施建议

**优先级**: 🔴 High  
**估算时间**: 30 分钟  
**影响范围**: `Sources/RosterApp/RootView.swift` 的 `RosterListToolbarControls`

**下一步**:
1. 实现方案 A 的代码
2. 测试不同窗口宽度
3. 验证 VoiceOver 支持
4. 添加键盘快捷键

---

**参考**:
- [Apple HIG - Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [Emil Kowalski - Simplicity](https://animations.dev/)

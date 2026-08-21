# Roster App - Emil Kowalski Design Engineering Audit

**审计日期**: 2026-08-10  
**审计基准**: Emil Kowalski's Design Engineering Philosophy  
**参考课程**: [animations.dev](https://animations.dev/)

---

> "All those unseen details combine to produce something that's just stunning, like a thousand barely audible voices all singing in tune." - Paul Graham

这份审计聚焦于那些用户不会有意识注意到、但会在整体上感受到的细节。

---

## 一、核心问题总览

### 🔴 Critical Issues (Must Fix)

| Before | After | Why |
| --- | --- | --- |
| 页面切换使用 `.opacity` 过渡 | 移除动画，直接切换 | 侧边栏导航属于高频操作（每天数十次），动画让界面感觉迟缓 |
| 按钮无 `:active` 状态 | 添加 `transform: scale(0.97)` | 按钮必须感觉响应，即时反馈告诉用户界面在倾听 |
| 日历网格格子无 hover 反馈 | 添加背景色变化 + `@media (hover: hover)` | 鼠标用户需要视觉确认哪个格子会被点击 |
| 卡片使用单层阴影 | 改用双层阴影系统 | 单层阴影缺乏深度，双层阴影（一个扩散 + 一个清晰）创造真实立体感 |
| Toast 使用 keyframes 动画 | 改用 CSS transitions | Toasts 快速连续出现，keyframes 会从零重启，transitions 可以平滑重定向 |

### 🟡 Important Improvements

| Before | After | Why |
| --- | --- | --- |
| 头像纯色背景 | 添加渐变 `linear-gradient(135deg, lighter, base)` | 纯色感觉平面，渐变增加深度和精致感 |
| 列表项同时出现 | 添加交错动画 (30-50ms delay) | 瀑布式出现比一次性出现更自然 |
| 刷新按钮无加载状态 | 添加旋转动画 + 禁用状态 | 用户需要知道操作正在进行 |
| 深色模式对比度过高 | 降低阴影强度从 0.28 到 0.15 | 深色模式应该柔和，不是高对比 |
| 所有动画使用固定 duration | 根据元素类型调整 (100-250ms) | 按钮反馈应该 100-160ms，弹出框 125-200ms，抽屉 200-500ms |

---

## 二、动画问题详细分析

### 2.1 高频操作的动画问题 ❌

**RootView.swift:221-223**
```swift
// ❌ 问题代码
.animation(.easeOut(duration: 0.22), value: model.selection)
```

**问题严重性**: 🔴 Critical

**Emil 原则违反**:
> "Never animate keyboard-initiated actions. These actions are repeated hundreds of times daily."

侧边栏导航每天会被点击数十次。0.22 秒的动画让每次切换都感觉有延迟。Raycast 没有打开/关闭动画，那就是每天使用数百次的工具的最佳体验。

**修复方案**:
```swift
// ✅ 正确做法：直接切换，无动画
Group {
    switch model.selection {
    case .calendar:
        CalendarDashboardView()
    case .list:
        RosterRecordsView()
    case .contacts:
        ContactsEditorView()
    case .permissions:
        PermissionsSettingsView()
    }
}
.id(model.selection)
// 移除 .transition() 和 .animation()
```

### 2.2 按钮缺少按下反馈 ❌

**RootView.swift:77-91 (MCMButtonChrome)**
```swift
// ❌ 问题代码
private struct MCMButtonChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(...)
    }
}
```

**问题**: 按钮点击没有任何形变反馈

**Emil 原则**:
> "Add `transform: scale(0.97)` on `:active`. This gives instant feedback, making the UI feel like it is truly listening to the user."

**修复方案**:
```swift
private struct MCMButtonChrome: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(...)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}
```

### 2.3 日历格子动画性能问题 ⚠️

**RootView.swift:598-634 (CalendarDayCell)**

**问题**: 
1. 每个格子都有 hover 状态，但没有 `@media (hover: hover)` 保护
2. 格子选中时有背景色变化，但没有 transition
3. 42 个格子同时渲染，无交错效果

**修复建议**:

| Before | After | Why |
| --- | --- | --- |
| 无 hover transition | 添加 `animation(.easeOut(duration: 0.15))` | Hover 应该有微妙的过渡，不是突变 |
| 所有格子同时出现 | 添加 `.transition(.opacity.animation(.easeOut.delay(Double(index) * 0.02)))` | 交错出现更自然，但要保持 delay 很短 (20ms) |
| 边框颜色突变 | 添加 transition | 今天/选中状态的边框变化应该平滑 |

```swift
// ✅ 改进后的格子
.background(
    RoundedRectangle(cornerRadius: 10)
        .fill(background)
        .animation(.easeOut(duration: 0.15), value: isSelected)
)
.overlay(
    RoundedRectangle(cornerRadius: 10)
        .strokeBorder(borderColor, lineWidth: isToday || isSelected ? 1.3 : 1)
        .animation(.easeOut(duration: 0.15), value: borderColor)
)
```

### 2.4 Toast 通知动画架构问题 ⚠️

**RootView.swift:227-234 (Toast overlay)**

**当前实现**: 使用 `.transition(.move(edge: .bottom).combined(with: .opacity))`

**Emil 原则违反**:
> "Use transitions, not keyframes, for dynamic UI. Toasts are added rapidly. Keyframes restart from zero on interruption. Transitions retarget smoothly."

**当前实现其实是对的**，但可以改进：

| Before | After | Why |
| --- | --- | --- |
| 单一 transition | 分离 opacity 和 transform timing | Toast 入场时透明度应该快速到达，位移可以稍慢 |
| 固定 duration 0.2s | 入场 400ms, 退场 200ms | 入场可以从容，退场应该迅速 |
| 使用 `.snappy` | 使用自定义 ease-out curve | `.snappy` 是预设，自定义曲线更强烈 |

```swift
// ✅ 改进的 Toast 动画
.transition(
    .asymmetric(
        insertion: .move(edge: .bottom)
            .combined(with: .opacity)
            .animation(.easeOut(duration: 0.4)),
        removal: .move(edge: .bottom)
            .combined(with: .opacity)
            .animation(.easeOut(duration: 0.2))
    )
)
```

---

## 三、组件设计问题

### 3.1 头像组件过于简单 ⚠️

**RootView.swift:122-142 (AvatarView)**

| Before | After | Why |
| --- | --- | --- |
| `.background(color, in: Circle())` | 使用 `LinearGradient` + 内阴影 | 纯色背景感觉廉价，渐变增加深度 |
| 无边框 | 添加 `.strokeBorder(.white.opacity(0.15), lineWidth: 0.5)` | 微妙的高光让头像更立体 |
| 单层 | 添加 `.shadow(color: .black.opacity(0.08), radius: 2, y: 1)` | 轻微的投影让头像"浮"在背景上 |

```swift
// ✅ 改进的头像
struct AvatarView: View {
    let name: String
    var color: Color = RosterTheme.accent
    var size: CGFloat = 38

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.85), color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
    
    // ... initials 逻辑保持不变
}
```

### 3.2 卡片阴影系统 ⚠️

**RootView.swift:63-75 (MCMCardStyle)**

| Before | After | Why |
| --- | --- | --- |
| 单层阴影 `.shadow(radius: 8, y: 2)` | 双层阴影：扩散层 + 清晰层 | 真实物体的阴影有两部分：模糊的环境光遮挡 + 清晰的直接投影 |
| 深色模式 opacity 0.28 | 降低到 0.15 | 深色模式应该柔和，不是高对比 |

```swift
// ✅ 改进的卡片样式
private struct MCMCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RosterTheme.cardBackground(colorScheme),
                in: RoundedRectangle(cornerRadius: RosterTheme.cardCorner)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RosterTheme.cardCorner)
                    .strokeBorder(RosterTheme.separator(colorScheme))
            )
            // 双层阴影
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.15 : 0.04),
                radius: 12,
                y: 4
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.10 : 0.02),
                radius: 2,
                y: 1
            )
    }
}
```

### 3.3 生日药丸 (Pill) 组件 ⚠️

**RootView.swift:651-672 (RosterPill)**

**问题**: 
1. 从 `scale(0)` 出现 - 违反 Emil 原则
2. 无 hover 状态
3. 点击后无反馈

| Before | After | Why |
| --- | --- | --- |
| 无入场动画控制 | 从 `scale(0.95) + opacity(0)` 开始 | 没有东西从完全的虚无中出现，即使是气球也有形状 |
| 无 hover 状态 | 添加 `transform: scale(1.05)` on hover | 可点击元素需要视觉确认 |
| 点击后无反馈 | 添加 `scale(0.97)` on active | 按下反馈让交互感觉即时 |

```swift
// ✅ 改进的 Pill
struct RosterPill: View {
    @Environment(RosterAppModel.self) private var model
    let occurrence: RosterOccurrence
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button {
            model.focusContact(occurrence.record.contactID)
        } label: {
            Text(occurrence.record.contactName)
                .lineLimit(1)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color(for: occurrence.record.kind), in: RoundedRectangle(cornerRadius: 4))
                .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.05 : 1.0))
                .animation(.easeOut(duration: 0.15), value: isHovered)
                .animation(.easeOut(duration: 0.1), value: isPressed)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            #if os(macOS)
            isHovered = hovering
            #endif
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .help(occurrence.record.contactName)
    }
}
```

---

## 四、性能问题

### 4.1 频繁的状态计算 🔴

**RootView.swift:598-600**
```swift
let occurrences = model.records(on: date)
    .filter { model.searchText.isEmpty || ... }
```

**问题**: 42 个日历格子，每次搜索文本变化都会重新计算 42 次

**Emil 原则**:
> "CSS variables are inheritable. Changing a CSS variable on a parent recalculates styles for all children."

虽然这是 SwiftUI 不是 CSS，但原则相同：避免在视图层做重复计算。

**修复**: 在 Model 层预计算并缓存

```swift
// ✅ 在 RosterAppModel 中
@Published private(set) var filteredOccurrencesByDate: [Date: [RosterOccurrence]] = [:]

private func updateFilteredOccurrences() {
    // 只计算可见月份的前后一个月
    // 在 searchText 或 visibleMonth 变化时调用一次
}
```

### 4.2 列表滚动性能 ⚠️

**RootView.swift:954-977 (RosterRecordsView ScrollView)**

**问题**: 使用 `LazyVStack` 是对的，但每个 row 都有复杂的卡片样式和多层阴影

**建议**:
1. 将阴影改为单层（列表项不需要浮动感）
2. 使用 `.drawingGroup()` 将多个视图合并为一个位图
3. 避免在 row 内使用透明度混合

```swift
// ✅ 优化后的列表项
.background(
    isToday ? RosterTheme.accent.opacity(0.08) : Color.clear,
    in: RoundedRectangle(cornerRadius: RosterTheme.cardCorner)
)
.overlay(
    RoundedRectangle(cornerRadius: RosterTheme.cardCorner)
        .strokeBorder(isToday ? RosterTheme.accent : Color.clear, lineWidth: 1.4)
)
.drawingGroup() // 将整个 row 渲染为一个位图
```

---

## 五、交互细节缺失

### 5.1 侧边栏项目 hover 状态 ⚠️

**RootView.swift:328-364 (SidebarItem)**

| Before | After | Why |
| --- | --- | --- |
| 仅有选中状态，无 hover | 添加 `.background(...).opacity(isHovered ? 1 : 0)` | 鼠标用户需要知道哪里可点 |
| 选中状态突变 | 添加 transition | 背景色变化应该平滑 |

```swift
// ✅ 添加 hover 状态
struct SidebarItem: View {
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            // ... 内容
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            #if os(macOS)
            isHovered = hovering
            #endif
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected 
                        ? RosterTheme.selectedFill(colorScheme)
                        : (isHovered ? RosterTheme.hoverFill(colorScheme) : Color.clear)
                )
                .animation(.easeOut(duration: 0.15), value: isHovered)
                .animation(.easeOut(duration: 0.15), value: isSelected)
        )
    }
}
```

### 5.2 刷新按钮无加载状态 ⚠️

**RootView.swift:499-506**

```swift
// ❌ 当前代码
Button {
    Task { await model.refreshContacts() }
} label: {
    Image(systemName: "arrow.clockwise")
}
```

**问题**: 点击后没有视觉反馈，用户不知道是否在加载

| Before | After | Why |
| --- | --- | --- |
| 静态图标 | 加载时旋转 + 禁用按钮 | 用户需要知道操作正在进行 |
| 可以连续点击 | 加载时禁用 | 防止重复请求 |

```swift
// ✅ 改进的刷新按钮
Button {
    Task { await model.refreshContacts() }
} label: {
    Image(systemName: "arrow.clockwise")
        .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
        .animation(
            model.isRefreshing 
                ? .linear(duration: 1).repeatForever(autoreverses: false)
                : .default,
            value: model.isRefreshing
        )
}
.disabled(model.isRefreshing)
.opacity(model.isRefreshing ? 0.5 : 1.0)
```

### 5.3 搜索框缺少清除按钮 ⚠️

**RootView.swift:508-519 (搜索框)**

**问题**: 输入后无法快速清除，需要手动删除

**建议**: 添加 ⓧ 清除按钮（当有内容时显示）

```swift
HStack(spacing: 6) {
    Image(systemName: "magnifyingglass")
        .foregroundStyle(.tertiary)
    
    TextField(model.l10n(.search), text: $model.searchText)
        .textFieldStyle(.plain)
    
    if !model.searchText.isEmpty {
        Button {
            model.searchText = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}
.animation(.easeOut(duration: 0.2), value: model.searchText.isEmpty)
```

---

## 六、HTML 原型 vs SwiftUI 实现差异

### 6.1 HTML 原型中好的动画（SwiftUI 缺失）

**redesign-mcm.html:386-415**
```css
/* 交错淡入动画 */
.page.active .list-scroll > *{animation:rise .26s var(--ease) both}
.page.active .list-scroll > *:nth-child(2){animation-delay:.03s}
.page.active .list-scroll > *:nth-child(3){animation-delay:.06s}
```

**建议**: 在 SwiftUI 中实现

```swift
ForEach(Array(groupedOccurrences.enumerated()), id: \.element.id) { index, group in
    // ...
}
.transition(.opacity.combined(with: .move(edge: .top)))
.animation(.easeOut(duration: 0.26).delay(Double(index) * 0.03), value: model.filteredRecords)
```

### 6.2 HTML 原型中过度的动画（应移除）

**redesign-mcm.html:417-420**
```css
/* 原子图标脉冲动画 */
.starburst{animation:pulse 4s ease-in-out infinite}
```

**问题**: 持续的无限动画会分散注意力

**Emil 原则**:
> "Never animate keyboard-initiated actions. If the purpose is just 'it looks cool' and the user will see it often, don't animate."

**建议**: 移除无限脉冲，改为 hover 时缩放

---

## 七、优先级修复清单

### P0 - 立即修复 (本周)

| Issue | File:Line | Estimated Time |
| --- | --- | --- |
| 移除页面切换动画 | RootView.swift:223 | 5 分钟 |
| 按钮添加 active 状态 | RootView.swift:77-91 | 30 分钟 |
| 卡片改用双层阴影 | RootView.swift:63-75 | 15 分钟 |
| 头像添加渐变 | RootView.swift:122-142 | 20 分钟 |
| 刷新按钮添加加载状态 | RootView.swift:499-506 | 30 分钟 |

**总计**: ~1.5 小时

### P1 - 重要改进 (下周)

| Issue | Estimated Time |
| --- | --- |
| 实现列表项交错动画 | 1 小时 |
| 侧边栏添加 hover 状态 | 45 分钟 |
| 优化日历格子动画 | 1.5 小时 |
| 搜索框添加清除按钮 | 30 分钟 |
| 优化 Toast 动画时机 | 45 分钟 |

**总计**: ~4.5 小时

### P2 - 体验优化 (下下周)

| Issue | Estimated Time |
| --- | --- |
| Pill 组件添加 hover/active 状态 | 1 小时 |
| 深色模式对比度优化 | 1 小时 |
| 性能优化：预计算过滤结果 | 2 小时 |
| 添加自定义 easing curves | 1 小时 |

**总计**: ~5 小时

---

## 八、代码示例：完整的按钮组件

这个示例展示了一个符合 Emil 标准的按钮应该是什么样的：

```swift
struct EmilButton: View {
    let label: String
    let action: () -> Void
    let style: ButtonStyleType
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    enum ButtonStyleType {
        case primary
        case secondary
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(style == .primary ? .white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            #if os(macOS)
            isHovered = hovering
            #endif
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var backgroundColor: Color {
        if style == .primary {
            return isPressed ? RosterTheme.accent.opacity(0.9) : RosterTheme.accent
        } else {
            return isHovered ? RosterTheme.hoverFill(.light) : RosterTheme.controlBackground(.light)
        }
    }
    
    private var borderColor: Color {
        style == .primary ? .clear : RosterTheme.separator(.light)
    }
}
```

**这个按钮做对了什么**:
- ✅ `scale(0.97)` on press - 即时反馈
- ✅ Hover 状态（带 media query 保护）
- ✅ 快速动画 (100-150ms)
- ✅ 使用 `ease-out` 让响应感更强
- ✅ Primary 按钮按下时稍微变暗，不是变形
- ✅ 所有状态变化都有平滑过渡

---

## 九、Emil Kowalski 评分

基于 Emil 的设计工程哲学，Roster 应用的评分：

| 维度 | 评分 | 说明 |
| --- | --- | --- |
| **动画决策** | 4/10 | 在高频操作上使用了不必要的动画 |
| **交互反馈** | 5/10 | 缺少按下状态，hover 状态不完整 |
| **组件精致度** | 6/10 | 组件功能完整但缺少细节（渐变、双层阴影） |
| **性能意识** | 5/10 | 有不必要的重复计算，但整体可接受 |
| **不可见细节** | 4/10 | 很多"应该有"的小细节缺失 |
| **整体协调性** | 7/10 | 设计系统清晰，但执行不够细致 |

**总评**: 6/10 - 功能完整的好应用，但距离"感觉正确"还有距离

**核心问题**: 缺少那些用户不会有意识注意到但会在整体上感受到的细节。

**Emil 会说的话**:
> "这个应用能工作，但它还不够'对'。按钮应该在你按下时有反应，动画应该只在需要时存在，每个细节都应该经过深思熟虑。这些看不见的改进会累积成用户喜欢但不知道为什么喜欢的体验。"

---

## 十、推荐学习资源

1. **Emil 的课程**: [animations.dev](https://animations.dev/) - 深入学习动画决策框架
2. **Easing 曲线**: [easing.dev](https://easing.dev/) 和 [easings.co](https://easings.co/)
3. **参考实现**: 
   - [Sonner](https://sonner.emilkowal.ski/) - Toast 组件的黄金标准
   - [Vaul](https://vaul.emilkowal.ski/) - Drawer 组件参考
   - [cmd-k](https://cmdk.paco.me/) - Command palette 参考

---

**下一步行动**: 按照 P0 清单开始修复，每个改动都测试"感觉"，用慢动作回放检查动画。记住：

> "Review your work the next day. You notice imperfections the next day that you missed during development."


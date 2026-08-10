import BirthdayCore
import SwiftUI

// MARK: - Root

struct RootView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var calendarMode = CalendarDisplayMode.month
    @State private var isSidebarCollapsed = false

    private var sidebarWidth: CGFloat {
        isSidebarCollapsed ? BirthdayTheme.Layout.sidebarCollapsedWidth : BirthdayTheme.Layout.sidebarWidth
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            AppToolbar(
                calendarMode: $calendarMode,
                isSidebarCollapsed: $isSidebarCollapsed,
                sidebarWidth: sidebarWidth
            )
                .frame(height: 54)

            Rectangle()
                .fill(BirthdayTheme.separator(colorScheme))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                SidebarView(isCollapsed: isSidebarCollapsed)
                    .frame(width: sidebarWidth)

                Rectangle()
                    .fill(BirthdayTheme.separator(colorScheme))
                    .frame(width: 0.5)

                ZStack {
                    BirthdayTheme.windowBackground(colorScheme)
                    currentPane
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BirthdayTheme.pageBackground(colorScheme))
        .animation(.snappy(duration: 0.2), value: isSidebarCollapsed)
        .overlay(alignment: .topTrailing) {
            if model.calculationProgress.isActive {
                CalculationProgressView(progress: model.calculationProgress)
                    .padding(18)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 22)
                    // Emil: 非对称动画 - 入场从容 (400ms), 退场迅速 (200ms)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity)
                                .animation(.easeOut(duration: 0.4)),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                                .animation(.easeOut(duration: 0.2))
                        )
                    )
            }
        }
        .tint(BirthdayTheme.accent)
        .alert("Birthday", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var currentPane: some View {
        switch model.selection {
        case .calendar:
            CalendarDashboardView(mode: $calendarMode)
        case .list:
            BirthdayRecordsView()
        case .contacts:
            ContactsEditorView()
        case .permissions:
            PermissionsSettingsView()
        }
    }
}

// MARK: - Global toolbar

struct AppToolbar: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Binding var calendarMode: CalendarDisplayMode
    @Binding var isSidebarCollapsed: Bool
    let sidebarWidth: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            toolbarTitle
                .frame(width: max(0, sidebarWidth - 24), alignment: .leading)

            Rectangle()
                .fill(BirthdayTheme.separator(colorScheme))
                .frame(width: 0.5)
                .padding(.vertical, -14)

            activeControls
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BirthdayTheme.pageBackground(colorScheme))
    }

    private var toolbarTitle: some View {
        HStack(spacing: 8) {
            ToolbarIconButton(
                systemImage: "sidebar.left",
                help: isSidebarCollapsed ? "展开边栏" : "收起边栏"
            ) {
                isSidebarCollapsed.toggle()
            }

            if !isSidebarCollapsed {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(BirthdayTheme.accent, in: RoundedRectangle(cornerRadius: 6))
                Text("Birthday")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var activeControls: some View {
        switch model.selection {
        case .calendar:
            CalendarToolbarControls(mode: $calendarMode)
        case .list:
            BirthdayListToolbarControls()
        case .contacts:
            ContactsToolbar()
        case .permissions:
            ToolbarTitle(text: model.l10n(.permissions))
        }
    }
}

struct ToolbarTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BirthdayListToolbarControls: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 12) {
            ToolbarTitle(text: model.l10n(.list))

            HStack(spacing: 7) {
                Text(model.l10n(.calendarKind))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker(model.l10n(.calendarKind), selection: $model.filter) {
                    Text(model.l10n(.all)).tag(BirthdayCalendarKind?.none)
                    ForEach(BirthdayCalendarKind.allCases) { kind in
                        Text(model.formatter.calendarName(kind, locale: model.language.coreLocale)).tag(Optional(kind))
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            HStack(spacing: 7) {
                Text(model.l10n(.sort))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker(model.l10n(.sort), selection: $model.sort) {
                    Text(model.l10n(.nearest)).tag(BirthdaySort.next)
                    Text(model.l10n(.name)).tag(BirthdaySort.name)
                    Text(model.l10n(.age)).tag(BirthdaySort.age)
                    Text(model.l10n(.calendarKind)).tag(BirthdaySort.calendar)
                }
                .pickerStyle(.segmented)
                .frame(width: 330)
            }

            SearchField(text: $model.searchText, prompt: model.l10n(.search))
                .frame(width: 220)

            Text("\(model.filteredRecords.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
        }
    }
}

struct CalendarToolbarControls: View {
    @Environment(BirthdayAppModel.self) private var model
    @Binding var mode: CalendarDisplayMode

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 12) {
            Text(model.visibleMonthTitle)
                .font(.system(size: 15, weight: .semibold))
                .frame(minWidth: 112, alignment: .leading)
                .contentTransition(.numericText())

            HStack(spacing: 4) {
                ToolbarIconButton(systemImage: "chevron.left", help: model.l10n(.previousMonth)) {
                    model.visibleMonth = Calendar.current.date(byAdding: .month, value: -1, to: model.visibleMonth) ?? model.visibleMonth
                }
                .accessibilityHint(model.l10n(.navigateToPreviousMonth))

                ToolbarIconButton(systemImage: "chevron.right", help: model.l10n(.nextMonth)) {
                    model.visibleMonth = Calendar.current.date(byAdding: .month, value: 1, to: model.visibleMonth) ?? model.visibleMonth
                }
                .accessibilityHint(model.l10n(.navigateToNextMonth))
            }

            Button(model.l10n(.today)) {
                model.visibleMonth = Date()
                model.selectedDate = Date()
            }
            .font(.system(size: 12.5, weight: .medium))
            .buttonStyle(.bordered)

            Spacer(minLength: 0)

            Picker("", selection: $mode) {
                Text(model.l10n(.month)).tag(CalendarDisplayMode.month)
                Text(model.l10n(.upcoming)).tag(CalendarDisplayMode.upcoming)
            }
            .pickerStyle(.segmented)
            .frame(width: 132)

            ToolbarIconButton(
                systemImage: "arrow.clockwise",
                help: model.l10n(.refreshContacts),
                isLoading: model.isLoading
            ) {
                Task { await model.refreshContacts() }
            }

            SearchField(text: $model.searchText, prompt: model.l10n(.search))
                .frame(width: 220)
        }
    }
}

struct SearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            // Emil: 添加清除按钮，有内容时显示
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(BirthdayTheme.controlBackground(colorScheme), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(BirthdayTheme.separator(colorScheme))
        )
        .animation(.easeOut(duration: 0.2), value: text.isEmpty)
    }
}

struct ToolbarIconButton: View {
    let systemImage: String
    let help: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 16, height: 16)
                // Emil: 加载时旋转动画，让用户知道操作正在进行
                .rotationEffect(.degrees(isLoading ? 360 : 0))
                .animation(
                    isLoading
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: isLoading
                )
        }
        .buttonStyle(.plain)
        .padding(6)
        .contentShape(Rectangle())
        .help(help)
        .accessibilityLabel(help)
    }
}

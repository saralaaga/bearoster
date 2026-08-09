import BirthdayCore
import SwiftUI

// MARK: - Calendar dashboard

struct CalendarDashboardView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var mode = CalendarMode.month

    private enum CalendarMode: String, CaseIterable, Identifiable {
        case month
        case upcoming
        var id: String { rawValue }
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(BirthdayTheme.separator(colorScheme))
                .frame(height: 1)

            if mode == .month {
                HStack(spacing: 0) {
                    MonthGridView()
                    Rectangle()
                        .fill(BirthdayTheme.separator(colorScheme))
                        .frame(width: 1)
                    DayDetailView(date: model.selectedDate)
                        .frame(width: BirthdayTheme.Layout.dayDetailWidth)
                }
            } else {
                UpcomingBirthdaysView()
            }
        }
        .background(BirthdayTheme.windowBackground(colorScheme))
    }

    private var toolbar: some View {
        @Bindable var model = model

        return HStack(spacing: 12) {
            Text(monthTitle(model.visibleMonth))
                .font(.system(size: 19, weight: .black))
                .tracking(0.4)
                .frame(minWidth: 112, alignment: .leading)
                .contentTransition(.numericText())

            HStack(spacing: 8) {
                Button {
                    model.visibleMonth = Calendar.current.date(byAdding: .month, value: -1, to: model.visibleMonth) ?? model.visibleMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                }
                .help(model.l10n(.previousMonth))
                .accessibilityLabel(model.l10n(.previousMonth))
                .accessibilityHint(model.l10n(.navigateToPreviousMonth))
                .mcmButtonStyle()

                Button {
                    model.visibleMonth = Calendar.current.date(byAdding: .month, value: 1, to: model.visibleMonth) ?? model.visibleMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .help(model.l10n(.nextMonth))
                .accessibilityLabel(model.l10n(.nextMonth))
                .accessibilityHint(model.l10n(.navigateToNextMonth))
                .mcmButtonStyle()
            }

            Button(model.l10n(.today)) {
                model.visibleMonth = Date()
                model.selectedDate = Date()
            }
            .font(.system(size: 12.5, weight: .bold))
            .mcmButtonStyle()

            Spacer()

            Image(systemName: "atom")
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(BirthdayTheme.inkSecondary.opacity(0.16))
                .frame(width: 50)

            Picker("", selection: $mode) {
                Text(model.l10n(.month)).tag(CalendarMode.month)
                Text(model.l10n(.upcoming)).tag(CalendarMode.upcoming)
            }
            .pickerStyle(.segmented)
            .frame(width: 132)

            Button {
                Task { await model.refreshContacts() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
            }
            .help(model.l10n(.refreshContacts))
            .accessibilityLabel(model.l10n(.refreshContacts))
            .mcmButtonStyle()

            TextField(model.l10n(.search), text: $model.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(width: 180)
                .background(BirthdayTheme.controlBackground(colorScheme), in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner))
                .overlay(
                    RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner)
                        .strokeBorder(BirthdayTheme.separator(colorScheme))
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(BirthdayTheme.windowBackground(colorScheme))
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.coreLocale.rawValue)
        formatter.dateFormat = model.language.coreLocale == .english ? "MMMM yyyy" : "yyyy年M月"
        return formatter.string(from: date)
    }
}

struct MonthGridView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    private static let columns = Array(repeating: GridItem(.flexible(minimum: 64), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: Self.columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BirthdayTheme.inkTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 4)

            ScrollView {
                LazyVGrid(columns: Self.columns, spacing: 6) {
                    ForEach(monthDays, id: \.self) { date in
                        CalendarDayCell(date: date, inDisplayedMonth: isInDisplayedMonth(date))
                            .frame(minHeight: 94)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .background(BirthdayTheme.windowBackground(colorScheme))
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.coreLocale.rawValue)
        return formatter.shortStandaloneWeekdaySymbols
    }

    private var monthDays: [Date] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: model.visibleMonth)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: startOfMonth) - 1
        guard let start = calendar.date(byAdding: .day, value: -weekday, to: startOfMonth) else {
            return []
        }
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 31
        let cells = Int(ceil(Double(weekday + daysInMonth) / 7.0)) * 7
        return (0..<cells).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func isInDisplayedMonth(_ date: Date) -> Bool {
        Calendar.current.component(.month, from: date) == Calendar.current.component(.month, from: model.visibleMonth)
    }
}

struct CalendarDayCell: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let date: Date
    let inDisplayedMonth: Bool

    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var isSelected: Bool { Calendar.current.isDate(model.selectedDate, inSameDayAs: date) }

    var body: some View {
        let occurrences = model.filteredRecords(on: date)

        Button {
            model.selectedDate = date
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 12.5, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? .white : (inDisplayedMonth ? Color.primary : BirthdayTheme.inkTertiary))
                    .frame(width: 24, height: 24)
                    .background(isToday ? BirthdayTheme.accent : Color.clear, in: Circle())

                ForEach(occurrences.prefix(2)) { occurrence in
                    BirthdayPill(occurrence: occurrence)
                }
                if occurrences.count > 2 {
                    Text("+ \(occurrences.count - 2)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(borderColor, lineWidth: isToday || isSelected ? 1.3 : 1)
            )
            .saturation(inDisplayedMonth ? 1 : 0)
            .opacity(inDisplayedMonth ? 1 : 0.45)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var background: Color {
        if isSelected { return BirthdayTheme.mustard.opacity(colorScheme == .dark ? 0.14 : 0.22) }
        if inDisplayedMonth { return BirthdayTheme.cardBackground(colorScheme) }
        return .clear
    }

    private var borderColor: Color {
        if isToday { return BirthdayTheme.accent }
        if isSelected { return BirthdayTheme.mustard }
        return inDisplayedMonth ? BirthdayTheme.separator(colorScheme) : .clear
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.coreLocale.rawValue)
        formatter.dateStyle = .full
        let count = model.filteredRecords(on: date).count
        if count == 0 { return formatter.string(from: date) }
        return "\(formatter.string(from: date)), \(count)"
    }
}

struct BirthdayPill: View {
    @Environment(BirthdayAppModel.self) private var model
    let occurrence: BirthdayOccurrence

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
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(occurrence.record.contactName)
        .accessibilityLabel("\(model.l10n(.openContact)): \(occurrence.record.contactName)")
    }
}

// MARK: - Day detail

struct DayDetailView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let date: Date

    var body: some View {
        let occurrences = model.selectedDateOccurrences

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle)
                        .font(.system(size: 20, weight: .black))
                    Text(daySubtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(BirthdayTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(occurrences) { occurrence in
                    DayOccurrenceCard(occurrence: occurrence)
                }

                if occurrences.isEmpty {
                    Text(model.l10n(.noBirthdayOnDay))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(BirthdayTheme.inkSecondary)
                        .lineSpacing(3)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                } else if Calendar.current.isDateInToday(date) {
                    Label(model.l10n(.today), systemImage: "asterisk")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(BirthdayTheme.inkSecondary)
                        .lineSpacing(3)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                }
            }
            .padding(18)
        }
        .background(BirthdayTheme.windowBackground(colorScheme))
    }

    private var dayTitle: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        if model.language.coreLocale == .english {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: model.language.coreLocale.rawValue)
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return "\(month)月\(day)日"
    }

    private var daySubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.coreLocale.rawValue)
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: date)
        if Calendar.current.isDateInToday(date) {
            return "\(weekday) · \(model.l10n(.today))"
        }
        return weekday
    }
}

struct DayOccurrenceCard: View {
    @Environment(BirthdayAppModel.self) private var model
    let occurrence: BirthdayOccurrence

    var body: some View {
        Button {
            model.focusContact(occurrence.record.contactID)
        } label: {
            HStack(spacing: 11) {
                AvatarView(name: occurrence.record.contactName, color: color(for: occurrence.record.kind), size: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(occurrence.record.contactName)
                        .font(.system(size: 14, weight: .bold))
                    HStack(spacing: 7) {
                        KindBadge(kind: occurrence.record.kind)
                        Text(detailText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(BirthdayTheme.inkSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.l10n(.openContact)): \(occurrence.record.contactName)")
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: BirthdayTheme.cardCorner)
                .strokeBorder(color(for: occurrence.record.kind), lineWidth: Calendar.current.isDateInToday(occurrence.date) ? 1.4 : 0)
        )
    }

    private var detailText: String {
        var parts = [model.formatter.originalDate(occurrence.record, locale: model.language.coreLocale)]
        if model.showAge, let age = occurrence.age {
            parts.append("\(age)")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Upcoming

struct UpcomingBirthdaysView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let occurrences = model.upcomingOccurrences()

        if occurrences.isEmpty {
            ContentUnavailableView(model.l10n(.noBirthdays), systemImage: "calendar.badge.exclamationmark")
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(occurrences) { occurrence in
                        BirthdayOccurrenceCard(occurrence: occurrence)
                    }
                }
                .padding(16)
            }
            .background(BirthdayTheme.windowBackground(colorScheme))
        }
    }
}

struct BirthdayOccurrenceCard: View {
    @Environment(BirthdayAppModel.self) private var model
    let occurrence: BirthdayOccurrence

    var body: some View {
        Button {
            model.focusContact(occurrence.record.contactID)
        } label: {
            HStack(spacing: 12) {
                AvatarView(name: occurrence.record.contactName, color: color(for: occurrence.record.kind), size: 38)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(occurrence.record.contactName)
                            .font(.system(size: 14, weight: .bold))
                        KindBadge(kind: occurrence.record.kind)
                    }
                    Text("\(model.formatter.originalDate(occurrence.record, locale: model.language.coreLocale)) → \(model.formatter.occurrenceDate(occurrence.date, locale: model.language.coreLocale))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BirthdayTheme.inkSecondary)
                }

                Spacer()

                if model.showAge, let age = occurrence.age {
                    Text("\(age)")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(.quaternary, in: Circle())
                }

                CountdownChip(days: model.resolver.daysUntil(occurrence.date))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.l10n(.openContact)): \(occurrence.record.contactName)")
        .cardStyle()
    }

    private var dateBlock: some View {
        let calendar = Calendar.current
        return VStack(spacing: 1) {
            Text("\(calendar.component(.day, from: occurrence.date))")
                .font(.title3.weight(.bold))
            Text(monthSymbol)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(color(for: occurrence.record.kind))
        .frame(width: 52, height: 52)
        .background(color(for: occurrence.record.kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var monthSymbol: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.coreLocale.rawValue)
        let monthIndex = Calendar.current.component(.month, from: occurrence.date) - 1
        if model.language.coreLocale == .english {
            return formatter.shortStandaloneMonthSymbols[monthIndex]
        }
        return "\(monthIndex + 1)月"
    }
}

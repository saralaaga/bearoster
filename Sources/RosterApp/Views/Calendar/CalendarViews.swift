import RosterCore
import RosterShared
import SwiftUI

// MARK: - Calendar dashboard

enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case month
    case upcoming
    var id: String { rawValue }
}

struct CalendarDashboardView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Binding var mode: CalendarDisplayMode

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            if mode == .month {
                HStack(spacing: 0) {
                    MonthGridView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Rectangle()
                        .fill(RosterTheme.separator(colorScheme))
                        .frame(width: 1)
                    DayDetailView(date: model.selectedDate)
                        .frame(width: RosterTheme.Layout.dayDetailWidth)
                }
            } else {
                UpcomingRostersView()
            }
        }
        .background(RosterTheme.windowBackground(colorScheme))
    }
}

struct MonthGridView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    private static let gridSpacing: CGFloat = 6
    private static let minRowHeight: CGFloat = 64
    private let calendar = Calendar(identifier: .gregorian)

    private var weeks: [[Date]] {
        let dates = model.visibleMonthDates
        return stride(from: 0, to: dates.count, by: 7).map {
            Array(dates[$0..<min($0 + 7, dates.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Self.gridSpacing) {
                ForEach(model.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RosterTheme.inkTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 4)

            GeometryReader { proxy in
                let rowHeight = Self.rowHeight(availableHeight: proxy.size.height, rowCount: weeks.count)

                ScrollView {
                    VStack(spacing: Self.gridSpacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            HStack(spacing: Self.gridSpacing) {
                                ForEach(week, id: \.self) { date in
                                    CalendarDayCell(
                                        date: date,
                                        occurrences: model.filteredRecords(on: date),
                                        inDisplayedMonth: isInDisplayedMonth(date),
                                        isSelected: calendar.isDate(model.selectedDate, inSameDayAs: date)
                                    )
                                }
                            }
                            .frame(height: rowHeight)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }
            }
        }
        .background(RosterTheme.windowBackground(colorScheme))
    }

    /// Evenly distributes the available height across the month's week rows,
    /// clamped to a minimum row height so very short windows scroll instead of squeezing.
    private static func rowHeight(availableHeight: CGFloat, rowCount: Int) -> CGFloat {
        let rows = CGFloat(max(rowCount, 1))
        let overhead = gridSpacing * (rows - 1) + 18 // row spacing + bottom padding
        return max(minRowHeight, (availableHeight - overhead) / rows)
    }

    private func isInDisplayedMonth(_ date: Date) -> Bool {
        calendar.component(.month, from: date) == calendar.component(.month, from: model.visibleMonth)
    }
}

struct CalendarDayCell: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let date: Date
    let occurrences: [RosterOccurrence]
    let inDisplayedMonth: Bool
    let isSelected: Bool
    private let calendar = Calendar(identifier: .gregorian)

    private var isToday: Bool { calendar.isDateInToday(date) }

    var body: some View {
        Button {
            model.selectedDate = date
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12.5, weight: isToday ? .bold : .semibold))
                    .foregroundStyle(isToday ? .white : (inDisplayedMonth ? Color.primary : RosterTheme.inkTertiary))
                    .frame(width: 24, height: 24)
                    .background(isToday ? RosterTheme.accent : Color.clear, in: Circle())

                ForEach(occurrences.prefix(2)) { occurrence in
                    RosterPill(occurrence: occurrence)
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
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
            )
            .saturation(inDisplayedMonth ? 1 : 0)
            .opacity(inDisplayedMonth ? 1 : 0.45)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var background: Color {
        if isSelected { return RosterTheme.accent.opacity(0.12) }
        if !occurrences.isEmpty { return RosterTheme.cardBackground(colorScheme) }
        return .clear
    }

    private var borderColor: Color {
        if isSelected { return RosterTheme.accent }
        if !occurrences.isEmpty { return RosterTheme.separator(colorScheme) }
        return .clear
    }

    private var accessibilityLabel: String {
        let text = model.formatter.fullDate(date, locale: model.language.coreLocale)
        let count = occurrences.count
        if count == 0 { return text }
        return "\(text), \(count)"
    }
}

struct RosterPill: View {
    let occurrence: RosterOccurrence

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color(for: occurrence.record.kind))
                .frame(width: 3)
            Text(occurrence.record.contactName)
                .lineLimit(1)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .foregroundStyle(color(for: occurrence.record.kind))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color(for: occurrence.record.kind).opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel(occurrence.record.contactName)
    }
}

// MARK: - Day detail

struct DayDetailView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let date: Date
    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        let occurrences = model.selectedDateOccurrences

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle)
                        .font(.system(size: 20, weight: .black))
                    Text(daySubtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(RosterTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(occurrences) { occurrence in
                    DayOccurrenceCard(occurrence: occurrence)
                }

                if occurrences.isEmpty {
                    Text(model.l10n(.noRosterOnDay))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(RosterTheme.inkSecondary)
                        .lineSpacing(3)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                } else if calendar.isDateInToday(date) {
                    Label(model.l10n(.today), systemImage: "asterisk")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(RosterTheme.inkSecondary)
                        .lineSpacing(3)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                }
            }
            .padding(18)
        }
        .background(RosterTheme.windowBackground(colorScheme))
    }

    private var dayTitle: String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        if model.language.coreLocale == .english {
            return model.formatter.monthDay(date, locale: model.language.coreLocale)
        }
        return "\(month)月\(day)日"
    }

    private var daySubtitle: String {
        let weekday = model.formatter.weekdayName(date, locale: model.language.coreLocale)
        if calendar.isDateInToday(date) {
            return "\(weekday) · \(model.l10n(.today))"
        }
        return weekday
    }
}

struct DayOccurrenceCard: View {
    @Environment(RosterAppModel.self) private var model
    let occurrence: RosterOccurrence
    private let calendar = Calendar(identifier: .gregorian)

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
                            .foregroundStyle(RosterTheme.inkSecondary)
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
            RoundedRectangle(cornerRadius: RosterTheme.cardCorner)
                .strokeBorder(color(for: occurrence.record.kind), lineWidth: calendar.isDateInToday(occurrence.date) ? 1.4 : 0)
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

struct UpcomingRostersView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let occurrences = model.cachedUpcomingOccurrences

        if occurrences.isEmpty {
            ContentUnavailableView(model.l10n(.noRosters), systemImage: "calendar.badge.exclamationmark")
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(occurrences) { occurrence in
                        RosterOccurrenceCard(occurrence: occurrence)
                    }
                }
                .padding(16)
            }
            .background(RosterTheme.windowBackground(colorScheme))
        }
    }
}

struct RosterOccurrenceCard: View {
    @Environment(RosterAppModel.self) private var model
    let occurrence: RosterOccurrence
    private let calendar = Calendar(identifier: .gregorian)

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
                        .foregroundStyle(RosterTheme.inkSecondary)
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
        model.formatter.monthSymbol(occurrence.date, locale: model.language.coreLocale)
    }
}

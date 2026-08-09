import BirthdayCore
import SwiftUI

// MARK: - Records list

private struct BirthdayMonthGroup: Identifiable {
    let id: String
    let title: String
    let occurrences: [BirthdayOccurrence]
}

struct BirthdayRecordsView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(model.l10n(.list))
                    .font(.system(size: 19, weight: .black))
                    .tracking(0.4)

                Spacer()

                Picker(model.l10n(.calendarKind), selection: $model.filter) {
                    Text(model.l10n(.all)).tag(BirthdayCalendarKind?.none)
                    ForEach(BirthdayCalendarKind.allCases) { kind in
                        Text(model.formatter.calendarName(kind, locale: model.language.coreLocale)).tag(Optional(kind))
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Picker(model.l10n(.sort), selection: $model.sort) {
                    Text(model.l10n(.nearest)).tag(BirthdaySort.next)
                    Text(model.l10n(.name)).tag(BirthdaySort.name)
                    Text(model.l10n(.age)).tag(BirthdaySort.age)
                    Text(model.l10n(.calendarKind)).tag(BirthdaySort.calendar)
                }
                .pickerStyle(.segmented)
                .frame(width: 330)

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

                Text("\(model.filteredRecords.count)")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(BirthdayTheme.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(BirthdayTheme.hoverFill(colorScheme), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)

            Rectangle()
                .fill(BirthdayTheme.separator(colorScheme))
                .frame(height: 1)

            if model.filteredRecords.isEmpty {
                ContentUnavailableView(model.l10n(.noBirthdays), systemImage: "magnifyingglass")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedOccurrences) { group in
                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                Text(group.title)
                                    .font(.system(size: 15, weight: .black))
                                Text("\(group.occurrences.count)")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .foregroundStyle(BirthdayTheme.inkTertiary)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 20)
                            .padding(.bottom, 9)

                            ForEach(group.occurrences) { occurrence in
                                BirthdayOccurrenceListRow(occurrence: occurrence)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .background(BirthdayTheme.windowBackground(colorScheme))
            }
        }
        .background(BirthdayTheme.windowBackground(colorScheme))
    }

    private var groupedOccurrences: [BirthdayMonthGroup] {
        let occurrences = model.filteredRecordOccurrences
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: occurrences) { occurrence in
            let components = calendar.dateComponents([.year, .month], from: occurrence.date)
            guard let year = components.year, let month = components.month else {
                return "unknown"
            }
            return String(format: "%04d-%02d", year, month)
        }
        return grouped.keys.sorted().compactMap { key in
            guard let items = grouped[key], let first = items.first else { return nil }
            return BirthdayMonthGroup(
                id: key,
                title: monthGroupTitle(for: first.date),
                occurrences: items
            )
        }
    }

    private func monthGroupTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.coreLocale.rawValue)
        formatter.dateFormat = model.language.coreLocale == .english ? "MMMM yyyy" : "yyyy年M月"
        return formatter.string(from: date)
    }
}

struct BirthdayOccurrenceListRow: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let occurrence: BirthdayOccurrence

    private var isToday: Bool { Calendar.current.isDateInToday(occurrence.date) }

    var body: some View {
        Button {
            model.focusContact(occurrence.record.contactID)
        } label: {
            HStack(spacing: 12) {
                AvatarView(name: occurrence.record.contactName, color: color(for: occurrence.record.kind), size: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(occurrence.record.contactName)
                        .font(.system(size: 14, weight: .bold))
                    HStack(spacing: 7) {
                        KindBadge(kind: occurrence.record.kind)
                        Text(metaText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(BirthdayTheme.inkSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
                CountdownChip(days: model.resolver.daysUntil(occurrence.date))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isToday ? BirthdayTheme.accent.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: BirthdayTheme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: BirthdayTheme.cardCorner)
                .strokeBorder(isToday ? BirthdayTheme.accent : Color.clear, lineWidth: 1.4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.l10n(.openContact)): \(occurrence.record.contactName)")
    }

    private var metaText: String {
        var parts = [
            model.formatter.originalDate(occurrence.record, locale: model.language.coreLocale),
            model.formatter.occurrenceDate(occurrence.date, locale: model.language.coreLocale)
        ]
        if model.showAge, let age = occurrence.age {
            parts.append("\(age)")
        }
        return parts.joined(separator: " · ")
    }
}

struct BirthdayRecordCard: View {
    @Environment(BirthdayAppModel.self) private var model
    let record: BirthdayRecord

    var body: some View {
        let occurrence = model.resolver.nextOccurrence(for: record, after: Date())

        HStack(spacing: 12) {
            AvatarView(name: record.contactName, color: color(for: record.kind), size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.contactName)
                        .font(.headline)
                    KindBadge(kind: record.kind)
                }
                Text(model.formatter.originalDate(record, locale: model.language.coreLocale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.showAge {
                Text(record.year == nil ? model.l10n(.unknownAge) : (occurrence?.age.map { "\($0)" } ?? "—"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.quaternary, in: Circle())
            }

            VStack(alignment: .trailing, spacing: 4) {
                if let occurrence {
                    CountdownChip(days: model.resolver.daysUntil(occurrence.date))
                    Text(model.formatter.occurrenceDate(occurrence.date, locale: model.language.coreLocale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

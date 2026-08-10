import BirthdayCore
import SwiftUI

// MARK: - Records list

struct BirthdayRecordsView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let locale = model.language.coreLocale
        let openContactText = model.l10n(.openContact)
        let todayText = model.l10n(.today)

        VStack(spacing: 0) {
            if model.filteredRecords.isEmpty {
                ContentUnavailableView(model.l10n(.noBirthdays), systemImage: "magnifyingglass")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.filteredRecordGroups) { group in
                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                Text(group.title)
                                    .font(.system(size: 15, weight: .semibold))
                                Text("\(group.occurrences.count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 9)

                            ForEach(group.occurrences) { occurrence in
                                let daysUntil = model.resolver.daysUntil(occurrence.date)
                                BirthdayOccurrenceListRow(
                                    contactName: occurrence.record.contactName,
                                    kind: occurrence.record.kind,
                                    kindTitle: shortKindName(occurrence.record.kind, model: model),
                                    metaText: metaText(for: occurrence, locale: locale),
                                    daysUntil: daysUntil,
                                    daysUntilText: daysUntil == 0 ? todayText : daysLeftText(daysUntil, locale: locale),
                                    isToday: Calendar.current.isDateInToday(occurrence.date),
                                    accessibilityLabel: "\(openContactText): \(occurrence.record.contactName)"
                                ) {
                                    model.focusContact(occurrence.record.contactID)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .background(BirthdayTheme.windowBackground(colorScheme))
            }
        }
        .background(BirthdayTheme.windowBackground(colorScheme))
    }

    private func metaText(for occurrence: BirthdayOccurrence, locale: CalendarFormattingService.AppLocale) -> String {
        var parts = [
            model.formatter.originalDate(occurrence.record, locale: locale),
            model.formatter.occurrenceDate(occurrence.date, locale: locale)
        ]
        if model.showAge, let age = occurrence.age {
            parts.append("\(age)")
        }
        return parts.joined(separator: " · ")
    }
}

struct BirthdayOccurrenceListRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let contactName: String
    let kind: BirthdayCalendarKind
    let kindTitle: String
    let metaText: String
    let daysUntil: Int
    let daysUntilText: String
    let isToday: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AvatarView(name: contactName, color: color(for: kind), size: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(contactName)
                        .font(.system(size: 13.5, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 7) {
                        StaticKindBadge(kind: kind, title: kindTitle)
                        Text(metaText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
                StaticCountdownChip(days: daysUntil, title: daysUntilText)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isToday ? BirthdayTheme.accent.opacity(0.10) : Color.clear)
        .overlay(alignment: .bottom) {
            BirthdayTheme.separator(colorScheme)
                .frame(height: 0.5)
                .padding(.leading, 62)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
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

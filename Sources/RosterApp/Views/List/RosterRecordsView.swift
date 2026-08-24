import RosterCore
import RosterShared
import SwiftUI

// MARK: - Records list

struct RosterRecordsView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let filterSignature = "\(model.filter?.rawValue ?? "all")|\(model.rosterTagFilter.cacheKey)|\(model.sort.rawValue)"

        VStack(spacing: 0) {
            if model.filteredRecords.isEmpty {
                ContentUnavailableView(model.l10n(.noRosters), systemImage: "magnifyingglass")
                    .transition(listStateTransition)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.filteredRecordListGroups) { group in
                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                Text(group.title)
                                    .font(.system(size: 15, weight: .semibold))
                                Text("\(group.items.count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 9)

                            ForEach(group.items) { item in
                                RosterOccurrenceListRow(
                                    contactName: item.contactName,
                                    tags: item.tags,
                                    kind: item.kind,
                                    kindTitle: item.kindTitle,
                                    metaText: item.metaText,
                                    daysUntil: item.daysUntil,
                                    daysUntilText: item.daysUntilText,
                                    isToday: item.isToday,
                                    accessibilityLabel: item.accessibilityLabel
                                ) {
                                    model.focusContact(item.contactID)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .background(RosterTheme.windowBackground(colorScheme))
                .id(filterSignature)
                .transition(listStateTransition)
            }
        }
        .background(RosterTheme.windowBackground(colorScheme))
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.filter)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.rosterTagFilter)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.sort)
    }

    private var listStateTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: 5))
    }

}

struct RosterOccurrenceListRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let contactName: String
    let tags: [ContactTag]
    let kind: RosterCalendarKind
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
                    HStack(spacing: 6) {
                        Text(contactName)
                            .font(.system(size: 13.5, weight: .medium))
                            .lineLimit(1)
                        ContactTagSummary(tags: tags, limit: 2, isCompact: true)
                    }
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
        .background(isToday ? RosterTheme.accent.opacity(0.10) : Color.clear)
        .overlay(alignment: .bottom) {
            RosterTheme.separator(colorScheme)
                .frame(height: 0.5)
                .padding(.leading, 62)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct RosterRecordCard: View {
    @Environment(RosterAppModel.self) private var model
    let record: RosterRecord

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

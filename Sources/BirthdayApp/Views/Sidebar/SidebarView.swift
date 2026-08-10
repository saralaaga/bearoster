import BirthdayCore
import SwiftUI

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let isCollapsed: Bool

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            SidebarSectionTitle(model.l10n(.browse), isCollapsed: isCollapsed)
            SidebarItem(
                title: model.l10n(.calendar),
                systemImage: "calendar",
                badge: nil,
                isSelected: model.selection == .calendar,
                isCollapsed: isCollapsed
            ) { model.selection = .calendar }
            SidebarItem(
                title: model.l10n(.list),
                systemImage: "gift.fill",
                badge: model.allRecords.count,
                isSelected: model.selection == .list,
                isCollapsed: isCollapsed
            ) { model.selection = .list }

            SidebarSectionTitle(model.l10n(.manage), isCollapsed: isCollapsed)
            SidebarItem(
                title: model.l10n(.contacts),
                systemImage: "person.crop.rectangle.stack",
                badge: model.profiles.count,
                isSelected: model.selection == .contacts,
                isCollapsed: isCollapsed
            ) { model.selection = .contacts }

            SidebarSectionTitle(model.l10n(.settings), isCollapsed: isCollapsed)
            SidebarItem(
                title: model.l10n(.permissions),
                systemImage: "gearshape",
                badge: nil,
                isSelected: model.selection == .permissions,
                isCollapsed: isCollapsed
            ) { model.selection = .permissions }

            Spacer(minLength: 16)

            if !isCollapsed, let next = model.cachedUpcomingOccurrences.first {
                NextBirthdayCard(occurrence: next)
                    .padding(.horizontal, 2)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .background(BirthdayTheme.sidebarBackground(colorScheme))
    }
}

struct SidebarSectionTitle: View {
    let title: String
    let isCollapsed: Bool

    init(_ title: String, isCollapsed: Bool) {
        self.title = title
        self.isCollapsed = isCollapsed
    }

    var body: some View {
        Group {
            if isCollapsed {
                Color.clear
                    .frame(height: 12)
            } else {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 14)
                    .padding(.bottom, 5)
                    .transition(.opacity)
            }
        }
    }
}

struct SidebarItem: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    let badge: Int?
    let isSelected: Bool
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCollapsed ? 0 : 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: isCollapsed ? 20 : 18)
                    .foregroundStyle(isSelected ? .white : .secondary)
                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .transition(.opacity)
                    Spacer(minLength: 0)
                    if let badge {
                        Text("\(badge)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(isSelected ? Color.white.opacity(0.16) : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                            .transition(.opacity)
                    }
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, isCollapsed ? 8 : 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(isSelected ? BirthdayTheme.selectedFill(colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(title)
    }
}

struct NextBirthdayCard: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let occurrence: BirthdayOccurrence

    var body: some View {
        Button {
            model.focusContact(occurrence.record.contactID)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label(model.l10n(.upcoming), systemImage: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    AvatarView(name: occurrence.record.contactName, color: color(for: occurrence.record.kind), size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(occurrence.record.contactName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(model.formatter.occurrenceDate(occurrence.date, locale: model.language.coreLocale))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    CountdownChip(days: model.resolver.daysUntil(occurrence.date))
                }
            }
            .foregroundStyle(.primary)
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.l10n(.openContact)): \(occurrence.record.contactName)")
        .background(BirthdayTheme.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(BirthdayTheme.separator(colorScheme))
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 2, y: 0.5)
    }
}

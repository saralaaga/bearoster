import BirthdayCore
import SwiftUI

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("BIRTHDAY")
                    .font(.system(size: 16, weight: .black))
                    .tracking(1.6)
                MCMStripes()
                    .frame(width: 178)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 18)

            SidebarSectionTitle(model.l10n(.browse))
            SidebarItem(
                title: model.l10n(.calendar),
                systemImage: "calendar",
                badge: nil,
                isSelected: model.selection == .calendar
            ) { model.selection = .calendar }
            SidebarItem(
                title: model.l10n(.list),
                systemImage: "gift.fill",
                badge: model.allRecords.count,
                isSelected: model.selection == .list
            ) { model.selection = .list }

            SidebarSectionTitle(model.l10n(.manage))
            SidebarItem(
                title: model.l10n(.contacts),
                systemImage: "person.crop.rectangle.stack",
                badge: model.profiles.count,
                isSelected: model.selection == .contacts
            ) { model.selection = .contacts }

            SidebarSectionTitle(model.l10n(.settings))
            SidebarItem(
                title: model.l10n(.permissions),
                systemImage: "gearshape",
                badge: nil,
                isSelected: model.selection == .permissions
            ) { model.selection = .permissions }

            Spacer(minLength: 16)

            if let next = model.upcomingOccurrences().first {
                NextBirthdayCard(occurrence: next)
                    .padding(.horizontal, 2)
            }
        }
        .padding(12)
        .background(BirthdayTheme.sidebarBackground(colorScheme))
    }
}

struct SidebarSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(BirthdayTheme.inkTertiary)
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 5)
    }
}

struct SidebarItem: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    let badge: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? BirthdayTheme.accent : BirthdayTheme.inkSecondary)
                Text(title)
                    .font(.system(size: 13.5, weight: isSelected ? .bold : .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let badge {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BirthdayTheme.inkSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(BirthdayTheme.hoverFill(colorScheme), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .foregroundStyle(isSelected ? BirthdayTheme.accent : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? BirthdayTheme.selectedFill(colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct NextBirthdayCard: View {
    @Environment(BirthdayAppModel.self) private var model
    let occurrence: BirthdayOccurrence

    var body: some View {
        Button {
            model.focusContact(occurrence.record.contactID)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label(model.l10n(.upcoming), systemImage: "asterisk")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(BirthdayTheme.mustard)

                HStack(spacing: 10) {
                    AvatarView(name: occurrence.record.contactName, color: .white.opacity(0.24), size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(occurrence.record.contactName)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        Text(model.formatter.occurrenceDate(occurrence.date, locale: model.language.coreLocale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    CountdownChip(days: model.resolver.daysUntil(occurrence.date))
                }
            }
            .foregroundStyle(Color(red: 0.96, green: 0.90, blue: 0.83))
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.l10n(.openContact)): \(occurrence.record.contactName)")
        .background(
            LinearGradient(colors: [BirthdayTheme.teak, BirthdayTheme.walnut], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: BirthdayTheme.cardCorner)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}

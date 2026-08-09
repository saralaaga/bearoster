import BirthdayCore
import SwiftUI

// MARK: - Contacts editor

struct ContactsEditorView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            HStack {
                Text(model.l10n(.contacts))
                    .font(.system(size: 19, weight: .black))
                    .tracking(0.4)
                Spacer()
                Button {
                    Task { await model.refreshContacts() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                }
                .help(model.l10n(.refreshContacts))
                .accessibilityLabel(model.l10n(.refreshContacts))
                .mcmButtonStyle()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)

            Rectangle()
                .fill(BirthdayTheme.separator(colorScheme))
                .frame(height: 1)

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    TextField(model.l10n(.search), text: $model.contactSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(BirthdayTheme.controlBackground(colorScheme), in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner))
                        .overlay(
                            RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner)
                                .strokeBorder(BirthdayTheme.separator(colorScheme))
                        )
                        .padding(12)

                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(model.filteredProfiles) { profile in
                                ContactListRow(
                                    profile: profile,
                                    isSelected: model.selectedProfile?.id == profile.id
                                ) {
                                    model.selectedContactID = profile.id
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 12)
                    }
                }
                .frame(width: BirthdayTheme.Layout.contactListWidth)

                Rectangle()
                    .fill(BirthdayTheme.separator(colorScheme))
                    .frame(width: 1)

                if let profile = model.selectedProfile {
                    ContactBirthdayEditor(profile: profile)
                        .id(profile.id)
                } else {
                    ContentUnavailableView(model.l10n(.contacts), systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BirthdayTheme.windowBackground(colorScheme))
    }
}

struct ContactListRow: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let profile: ContactBirthdayProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let firstRecord = profile.records.first
        let subtitle = firstRecord.map {
            model.formatter.originalDate($0, locale: model.language.coreLocale)
        } ?? model.l10n(.noBirthdays)

        Button(action: action) {
            HStack(spacing: 10) {
                AvatarView(
                    name: profile.displayName,
                    color: firstRecord.map { color(for: $0.kind) } ?? BirthdayTheme.inkTertiary,
                    size: 30
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.system(size: 13.5, weight: .bold))
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        if let firstRecord {
                            KindBadge(kind: firstRecord.kind)
                        }
                        Text(subtitle)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(BirthdayTheme.inkSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Circle()
                    .fill(profile.records.isEmpty ? BirthdayTheme.separator(colorScheme) : BirthdayTheme.olive)
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? BirthdayTheme.selectedFill(colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct ContactBirthdayEditor: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let profile: ContactBirthdayProfile
    @State private var draft: BirthdayEditDraft

    init(profile: ContactBirthdayProfile) {
        self.profile = profile
        _draft = State(initialValue: BirthdayEditDraft(profile: profile))
    }

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AvatarView(
                        name: profile.displayName,
                        color: profile.records.first.map { color(for: $0.kind) } ?? BirthdayTheme.accent,
                        size: 42
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.displayName)
                            .font(.system(size: 20, weight: .black))
                        if !profile.organizationName.isEmpty {
                            Text(profile.organizationName)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(BirthdayTheme.inkSecondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    formLabel(model.formatter.calendarName(.gregorian, locale: model.language.coreLocale))
                    HStack(spacing: 10) {
                        dateField("YYYY", text: $draft.gregorianYear, width: 82)
                        dateField("MM", text: $draft.gregorianMonth, width: 68)
                        dateField("DD", text: $draft.gregorianDay, width: 68)
                    }
                }
                .padding(18)
                .cardStyle()

                VStack(alignment: .leading, spacing: 14) {
                    formLabel(model.l10n(.calendarKind))
                    Picker(model.l10n(.calendarKind), selection: $draft.nonGregorianKind) {
                        Text("—").tag(BirthdayCalendarKind?.none)
                        Text(model.formatter.calendarName(.chinese, locale: model.language.coreLocale)).tag(Optional(BirthdayCalendarKind.chinese))
                        Text(model.formatter.calendarName(.hebrew, locale: model.language.coreLocale)).tag(Optional(BirthdayCalendarKind.hebrew))
                        Text(model.formatter.calendarName(.islamic, locale: model.language.coreLocale)).tag(Optional(BirthdayCalendarKind.islamic))
                    }
                    .pickerStyle(.segmented)

                    if draft.nonGregorianKind != nil {
                        formLabel(model.l10n(.originalDate))
                        HStack(spacing: 10) {
                            dateField("YYYY", text: $draft.nonGregorianYear, width: 82)
                            dateField("MM", text: $draft.nonGregorianMonth, width: 68)
                            dateField("DD", text: $draft.nonGregorianDay, width: 68)
                            if draft.nonGregorianKind == .chinese {
                                Toggle(model.l10n(.leapMonth), isOn: $draft.isLeapMonth)
                                    .toggleStyle(.switch)
                            }
                        }
                    }
                }
                .padding(18)
                .cardStyle()

                Text(model.l10n(.written))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BirthdayTheme.inkSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: 460, alignment: .leading)
                    .background(BirthdayTheme.hoverFill(colorScheme), in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner))
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .onChange(of: draft) { _, newDraft in
            model.scheduleSave(contactID: profile.id, draft: newDraft)
        }
    }

    private func formLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(BirthdayTheme.inkSecondary)
    }

    private func dateField(_ placeholder: String, text: Binding<String>, width: CGFloat) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13.5, weight: .medium))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(width: width)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner))
            .overlay(
                RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner)
                    .strokeBorder(BirthdayTheme.walnut.opacity(0.30))
            )
    }
}

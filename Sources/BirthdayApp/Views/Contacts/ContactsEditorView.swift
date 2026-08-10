import BirthdayCore
import SwiftUI

// MARK: - Contacts editor

struct ContactsEditorView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var model = model
        let selectedProfile = model.selectedProfile
        let selectedID = selectedProfile?.id

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ContactCollectionsPane()
                    .frame(width: 210)

                KimiSeparator(axis: .vertical)

                VStack(spacing: 0) {
                    ContactListHeader(count: model.visibleContactCount)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(model.contactListSections) { section in
                                Section {
                                    ForEach(section.rows) { row in
                                        ContactListRow(
                                            row: row,
                                            isSelected: selectedID == row.id
                                        ) {
                                            model.selectedContactID = row.id
                                        }
                                    }
                                } header: {
                                    ContactSectionHeader(title: section.title)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(ContactsNativeStyle.listBackground(colorScheme))
                }
                .frame(width: 300)

                KimiSeparator(axis: .vertical)

                ZStack {
                    ContactsNativeStyle.detailBackground(colorScheme)
                    if let profile = selectedProfile {
                        ContactBirthdayEditor(profile: profile)
                            .id(profile.id)
                    } else {
                        ContentUnavailableView(model.l10n(.contacts), systemImage: "person.crop.circle")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ContactsNativeStyle.windowBackground(colorScheme))
    }
}

// MARK: - Toolbar

struct ContactsToolbar: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 12) {
            Text(model.l10n(.contacts))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField(model.l10n(.search), text: $model.contactSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 240)
            .background(ContactsNativeStyle.searchBackground(colorScheme), in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(ContactsNativeStyle.separator(colorScheme))
            )

            Button {
                Task { await model.refreshContacts() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 15, height: 15)
                    // Emil: 加载时旋转动画
                    .rotationEffect(.degrees(model.isLoading ? 360 : 0))
                    .animation(
                        model.isLoading
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: model.isLoading
                    )
            }
            .help(model.l10n(.refreshContacts))
            .accessibilityLabel(model.l10n(.refreshContacts))
            .buttonStyle(.plain)
            .disabled(model.isLoading)
            .opacity(model.isLoading ? 0.5 : 1.0)
            .kimiToolbarButton()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Source list

struct ContactCollectionsPane: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(model.contactCollectionSections) { section in
                    ContactSourceSectionTitle(title: section.id == "all" ? model.l10n(.library) : section.title)
                    ForEach(section.collections) { collection in
                        ContactCollectionRow(
                            collection: collection,
                            isSelected: model.selectedContactCollectionID == collection.id
                        ) {
                            model.selectedContactCollectionID = collection.id
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(ContactsNativeStyle.sourceListBackground(colorScheme))
    }
}

struct ContactSourceSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }
}

struct ContactCollectionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let collection: ContactCollectionSummary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                collectionIcon
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(iconColor, in: RoundedRectangle(cornerRadius: 5))

                Text(collection.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(collection.contactCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? ContactsNativeStyle.accent : ContactsNativeStyle.sourceRowHover(colorScheme),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(collection.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var collectionIcon: Image {
        switch collection.kind {
        case .all: Image(systemName: "person.2.fill")
        case .container: Image(systemName: "tray.full.fill")
        case .group: Image(systemName: "folder.fill")
        }
    }

    private var iconColor: Color {
        switch collection.kind {
        case .all: ContactsNativeStyle.accent
        case .container: Color(hex: 0x8E8E93)
        case .group: Color(hex: 0xFF9500)
        }
    }
}

// MARK: - Contact list

struct ContactListHeader: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.l10n(.contacts))
                .font(.system(size: 20, weight: .bold))
            Text(contactCountText(count, locale: model.language.coreLocale))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            ContactsNativeStyle.separator(colorScheme)
                .frame(height: 0.5)
        }
    }
}

struct ContactSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ContactsNativeStyle.listBackground(colorScheme).opacity(0.96))
    }
}

struct ContactListRow: View {
    let row: ContactListRowModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AvatarView(
                    name: row.displayName,
                    color: row.kind.map(color(for:)) ?? Color(hex: 0x8E8E93),
                    size: 34
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.displayName)
                        .font(.system(size: 13.5, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        if let kind = row.kind, let kindTitle = row.kindTitle {
                            StaticKindBadge(kind: kind, title: kindTitle)
                        }
                        Text(row.subtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(isSelected ? .white.opacity(0.75) : .secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if let text = row.daysUntilText, let days = row.daysUntil {
                    Text(text)
                        .font(.system(size: 11, weight: days <= 7 ? .semibold : .regular))
                        .foregroundStyle(days <= 7 ? ContactsNativeStyle.red : (isSelected ? .white.opacity(0.75) : Color.secondary.opacity(0.75)))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? ContactsNativeStyle.accent : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail

struct ContactBirthdayEditor: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let profile: ContactBirthdayProfile
    @State private var draft: BirthdayEditDraft
    @State private var isEditing = false
    @State private var isSaving = false

    init(profile: ContactBirthdayProfile) {
        self.profile = profile
        _draft = State(initialValue: BirthdayEditDraft(profile: profile))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                countdownBanner

                if isEditing {
                    editCards
                } else {
                    readCards
                }

                actionBar
            }
            .padding(.horizontal, 32)
            .padding(.top, 34)
            .padding(.bottom, 60)
            .frame(maxWidth: 624)
            .frame(maxWidth: .infinity)
        }
        .background(ContactsNativeStyle.detailBackground(colorScheme))
        .animation(.easeOut(duration: 0.16), value: isEditing)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            AvatarView(name: profile.displayName, color: heroColor, size: 96)
            VStack(spacing: 3) {
                Text(isEditing ? model.l10n(.editContact) : profile.displayName)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                if !isEditing {
                    Text(detailTagline)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var countdownBanner: some View {
        if let occurrence = nextOccurrence {
            let days = model.resolver.daysUntil(occurrence.date)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    if days == 0 {
                        Text(model.l10n(.today))
                            .font(.system(size: 24, weight: .bold))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(days)")
                                .font(.system(size: 24, weight: .bold))
                                .monospacedDigit()
                            Text(daysSuffix)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(days == 0 ? .white.opacity(0.82) : .secondary)
                        }
                    }

                    Text(countdownSubtitle(for: occurrence))
                        .font(.system(size: 12))
                        .foregroundStyle(days == 0 ? .white.opacity(0.82) : .secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "birthday.cake")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(days == 0 ? .white.opacity(0.76) : .secondary.opacity(0.72))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .foregroundStyle(days == 0 ? .white : .primary)
            .background(days == 0 ? ContactsNativeStyle.red : ContactsNativeStyle.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(days == 0 ? Color.clear : ContactsNativeStyle.separator(colorScheme))
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 2, y: 0.5)
        }
    }

    private var readCards: some View {
        VStack(spacing: 18) {
            NativeInfoCard {
                NativeInfoRow(label: model.l10n(.birthday)) {
                    BirthdayValues(records: profile.records)
                }
                NativeDivider()
                NativeInfoRow(label: model.l10n(.nextBirthday)) {
                    Text(nextOccurrence.map { model.formatter.occurrenceDate($0.date, locale: model.language.coreLocale) } ?? model.l10n(.notFilled))
                }
                NativeDivider()
                NativeInfoRow(label: model.l10n(.age)) {
                    Text(nextOccurrence?.age.map { ageValueText($0) } ?? model.l10n(.unknownAge))
                }
                NativeDivider()
                NativeInfoRow(label: model.l10n(.group)) {
                    Text(groupText)
                        .foregroundStyle(groupText == model.l10n(.notFilled) ? .tertiary : .primary)
                }
            }

            if model.extendedContactFieldsEnabled,
               let extended = model.extendedProfilesByID[profile.id],
               extended.hasVisibleFields {
                ExtendedContactDetailsView(extended: extended)
            }
        }
    }

    private var editCards: some View {
        VStack(spacing: 18) {
            NativeInfoCard {
                NativeInfoRow(label: model.formatter.calendarName(.gregorian, locale: model.language.coreLocale)) {
                    HStack(spacing: 8) {
                        NativeDateField("YYYY", text: $draft.gregorianYear, width: 72)
                        NativeDateField("MM", text: $draft.gregorianMonth, width: 58)
                        NativeDateField("DD", text: $draft.gregorianDay, width: 58)
                    }
                }

                NativeDivider()

                NativeInfoRow(label: model.l10n(.calendarKind)) {
                    Picker(model.l10n(.calendarKind), selection: $draft.nonGregorianKind) {
                        Text("-").tag(BirthdayCalendarKind?.none)
                        Text(model.formatter.calendarName(.chinese, locale: model.language.coreLocale)).tag(Optional(BirthdayCalendarKind.chinese))
                        Text(model.formatter.calendarName(.hebrew, locale: model.language.coreLocale)).tag(Optional(BirthdayCalendarKind.hebrew))
                        Text(model.formatter.calendarName(.islamic, locale: model.language.coreLocale)).tag(Optional(BirthdayCalendarKind.islamic))
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if draft.nonGregorianKind != nil {
                    NativeDivider()
                    NativeInfoRow(label: model.l10n(.originalDate)) {
                        HStack(spacing: 8) {
                            NativeDateField("YYYY", text: $draft.nonGregorianYear, width: 72)
                            NativeDateField("MM", text: $draft.nonGregorianMonth, width: 58)
                            NativeDateField("DD", text: $draft.nonGregorianDay, width: 58)
                            if draft.nonGregorianKind == .chinese {
                                Toggle(model.l10n(.leapMonth), isOn: $draft.isLeapMonth)
                                    .toggleStyle(.switch)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
            }

            if model.extendedContactFieldsEnabled,
               let extended = model.extendedProfilesByID[profile.id],
               extended.hasVisibleFields {
                ExtendedContactDetailsView(extended: extended)
                Text(model.l10n(.readOnlyExtendedFields))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 3)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if isEditing {
                Button {
                    saveDraft()
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 42)
                    } else {
                        Text(model.l10n(.done))
                    }
                }
                .buttonStyle(KimiActionButtonStyle(kind: .primary))
                .disabled(draft.payload == nil || isSaving)

                Button {
                    draft = BirthdayEditDraft(profile: profile)
                    isEditing = false
                } label: {
                    Text(model.l10n(.cancel))
                }
                .buttonStyle(KimiActionButtonStyle(kind: .regular))
                .disabled(isSaving)
            } else {
                Button {
                    draft = BirthdayEditDraft(profile: profile)
                    isEditing = true
                } label: {
                    Text(model.l10n(.edit))
                }
                .buttonStyle(KimiActionButtonStyle(kind: .primary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var nextOccurrence: BirthdayOccurrence? {
        profile.records
            .compactMap { model.resolver.nextOccurrence(for: $0, after: Date()) }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.record.kind.rawValue < rhs.record.kind.rawValue
            }
            .first
    }

    private var groupText: String {
        let groupIDs = model.contactGrouping.groupIDsByContactID[profile.id] ?? []
        let titles = model.contactGrouping.groups
            .filter { groupIDs.contains($0.id) }
            .map(\.name)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return titles.isEmpty ? model.l10n(.notFilled) : titles.joined(separator: ", ")
    }

    private var detailTagline: String {
        if !groupText.isEmpty, groupText != model.l10n(.notFilled) {
            return groupText
        }
        if !profile.organizationName.isEmpty {
            return profile.organizationName
        }
        return model.l10n(.contactsSource)
    }

    private var heroColor: Color {
        profile.records.first.map { color(for: $0.kind) } ?? ContactsNativeStyle.accent
    }

    private var daysSuffix: String {
        switch model.language.coreLocale {
        case .english: "days"
        case .simplifiedChinese: "天后"
        case .traditionalChinese: "天後"
        }
    }

    private func countdownSubtitle(for occurrence: BirthdayOccurrence) -> String {
        let date = model.formatter.occurrenceDate(occurrence.date, locale: model.language.coreLocale)
        guard let age = occurrence.age else { return date }
        return "\(date) · \(ageValueText(age))"
    }

    private func ageValueText(_ age: Int) -> String {
        switch model.language.coreLocale {
        case .english: "Turns \(age)"
        case .simplifiedChinese: "满 \(age) 岁"
        case .traditionalChinese: "滿 \(age) 歲"
        }
    }

    private func saveDraft() {
        guard let payload = draft.payload else { return }
        Task { @MainActor in
            isSaving = true
            await model.save(contactID: profile.id, payload: payload)
            isSaving = false
            isEditing = false
        }
    }
}

struct BirthdayValues: View {
    @Environment(BirthdayAppModel.self) private var model
    let records: [BirthdayRecord]

    var body: some View {
        if records.isEmpty {
            Text(model.l10n(.noBirthdays))
                .foregroundStyle(.tertiary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(records) { record in
                    HStack(spacing: 7) {
                        StaticKindBadge(kind: record.kind, title: shortKindName(record.kind, model: model))
                        Text(model.formatter.originalDate(record, locale: model.language.coreLocale))
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - Extended details

struct ExtendedContactDetailsView: View {
    @Environment(BirthdayAppModel.self) private var model
    let extended: ContactExtendedProfile

    var body: some View {
        NativeInfoCard {
            ForEach(Array(infoGroups.enumerated()), id: \.element.id) { index, group in
                if index > 0 {
                    NativeDivider()
                }
                NativeInfoRow(label: group.title) {
                    InfoValueStack(values: group.values)
                }
            }
        }
    }

    private var infoGroups: [ExtendedInfoGroup] {
        [
            ExtendedInfoGroup(id: "work", title: model.l10n(.work), values: [extended.jobTitle, extended.departmentName]),
            ExtendedInfoGroup(id: "phone", title: model.l10n(.phone), values: extended.phoneNumbers),
            ExtendedInfoGroup(id: "email", title: model.l10n(.email), values: extended.emailAddresses),
            ExtendedInfoGroup(id: "address", title: model.l10n(.address), values: extended.postalAddresses),
            ExtendedInfoGroup(id: "links", title: model.l10n(.links), values: extended.urlAddresses + extended.socialProfiles + extended.instantMessageAddresses),
            ExtendedInfoGroup(id: "dates", title: model.l10n(.dates), values: extended.dates),
            ExtendedInfoGroup(id: "relations", title: model.l10n(.relations), values: extended.contactRelations)
        ]
        .map { group in
            ExtendedInfoGroup(
                id: group.id,
                title: group.title,
                values: group.values.filter { !$0.isEmpty }
            )
        }
        .filter { !$0.values.isEmpty }
    }
}

private struct ExtendedInfoGroup: Identifiable {
    let id: String
    let title: String
    let values: [String]
}

struct InfoValueStack: View {
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(values.prefix(4), id: \.self) { value in
                Text(value)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Native cards

struct NativeInfoCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(ContactsNativeStyle.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ContactsNativeStyle.separator(colorScheme))
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 2, y: 0.5)
    }
}

struct NativeInfoRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .trailing)

            content
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }
}

struct NativeDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ContactsNativeStyle.separator(colorScheme)
            .frame(height: 0.5)
            .padding(.leading, 108)
    }
}

struct NativeDateField: View {
    @Environment(\.colorScheme) private var colorScheme
    let placeholder: String
    @Binding var text: String
    let width: CGFloat

    init(_ placeholder: String, text: Binding<String>, width: CGFloat) {
        self.placeholder = placeholder
        _text = text
        self.width = width
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13.5))
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: width)
            .background(ContactsNativeStyle.inputFocusBackground(colorScheme), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(ContactsNativeStyle.separator(colorScheme))
            )
    }
}

// MARK: - Styles

private enum KimiSeparatorAxis {
    case horizontal
    case vertical
}

private struct KimiSeparator: View {
    @Environment(\.colorScheme) private var colorScheme
    let axis: KimiSeparatorAxis

    var body: some View {
        ContactsNativeStyle.separator(colorScheme)
            .frame(width: axis == .vertical ? 0.5 : nil, height: axis == .horizontal ? 0.5 : nil)
    }
}

private enum KimiActionButtonKind {
    case regular
    case primary
}

private struct KimiActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    let kind: KimiActionButtonKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .frame(minWidth: 76)
            .background(background(configuration: configuration), in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(kind == .primary ? Color.clear : ContactsNativeStyle.strongSeparator(colorScheme))
            )
            .shadow(color: .black.opacity(kind == .primary || colorScheme == .dark ? 0 : 0.08), radius: 1.5, y: 0.5)
            .opacity(isEnabled ? 1 : 0.52)
    }

    private var foreground: Color {
        switch kind {
        case .regular: .primary
        case .primary: .white
        }
    }

    private func background(configuration: Configuration) -> Color {
        switch kind {
        case .regular:
            return configuration.isPressed ? ContactsNativeStyle.pressedBackground(colorScheme) : ContactsNativeStyle.cardBackground(colorScheme)
        case .primary:
            return configuration.isPressed ? Color(hex: 0x0062CC) : ContactsNativeStyle.accent
        }
    }
}

private struct KimiToolbarButtonChrome: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(isHovering ? ContactsNativeStyle.sourceRowHover(colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private extension View {
    func kimiToolbarButton() -> some View {
        modifier(KimiToolbarButtonChrome())
    }
}

private enum ContactsNativeStyle {
    static let accent = Color(hex: 0x007AFF)
    static let red = Color(hex: 0xFF3B30)

    static func toolbarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(hex: 0xF5F5F7)
    }

    static func sourceListBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .underPageBackgroundColor) : Color(hex: 0xF2F2F7)
    }

    static func windowBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color.white
    }

    static func listBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color.white
    }

    static func detailBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .underPageBackgroundColor) : Color(hex: 0xF5F5F7)
    }

    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .controlBackgroundColor) : Color.white
    }

    static func searchBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.86)
    }

    static func sourceRowHover(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.0001)
    }

    static func inputFocusBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : accent.opacity(0.06)
    }

    static func pressedBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color(hex: 0xE8E8E8)
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.10)
    }

    static func strongSeparator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.18)
    }
}

private func contactCountText(_ count: Int, locale: CalendarFormattingService.AppLocale) -> String {
    switch locale {
    case .english: count == 1 ? "1 contact" : "\(count) contacts"
    case .simplifiedChinese: "\(count) 位联系人"
    case .traditionalChinese: "\(count) 位聯絡人"
    }
}

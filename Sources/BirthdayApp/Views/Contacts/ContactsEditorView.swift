import BirthdayCore
import SwiftUI

// MARK: - Contacts editor

struct ContactsEditorView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        let selectedProfile = model.selectedProfile
        let selectedID = model.isContactSelectionMode ? nil : selectedProfile?.id

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ContactCollectionsPane()
                    .fixedContactColumn(width: ContactsLayout.collectionsWidth, priority: 3)

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
                                            isSelected: selectedID == row.id,
                                            isSelectionMode: model.isContactSelectionMode,
                                            isMarkedForDeletion: model.selectedContactIDsForDeletion.contains(row.id)
                                        ) {
                                            if model.isContactSelectionMode {
                                                model.toggleContactDeletionSelection(row.id)
                                            } else {
                                                model.selectedContactID = row.id
                                            }
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
                .fixedContactColumn(width: ContactsLayout.listWidth, priority: 2)

                KimiSeparator(axis: .vertical)

                ZStack {
                    ContactsNativeStyle.detailBackground(colorScheme)
                    if model.isContactSelectionMode {
                        BulkContactSelectionView()
                            .transition(.opacity)
                    } else if let profile = selectedProfile {
                        ContactBirthdayEditor(profile: profile)
                            .id(profile.id)
                            .transition(.opacity)
                    } else {
                        ContentUnavailableView(model.l10n(.contacts), systemImage: "person.crop.circle")
                            .transition(.opacity)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)
                .clipped()
                .animation(BirthdayTheme.Motion.allowed(BirthdayTheme.Motion.stateChange, reduceMotion: reduceMotion), value: model.isContactSelectionMode)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ContactsNativeStyle.windowBackground(colorScheme))
    }
}

private enum ContactsLayout {
    static let collectionsWidth: CGFloat = 210
    static let listWidth: CGFloat = 300
}

// MARK: - Toolbar

struct ContactsToolbar: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isConfirmingDeletion = false

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 12) {
            Text(model.l10n(.contacts))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            if model.isContactSelectionMode {
                selectionControls
            } else {
                normalControls
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(model.l10n(.deleteContactsTitle), isPresented: $isConfirmingDeletion) {
            Button(model.l10n(.deleteContacts), role: .destructive) {
                Task { await model.deleteSelectedContacts() }
            }
            Button(model.l10n(.cancel), role: .cancel) { }
        } message: {
            Text(model.l10n(.deleteContactsMessage))
        }
    }

    private var normalControls: some View {
        @Bindable var model = model

        return HStack(spacing: 12) {
            Button(model.l10n(.selectContacts)) {
                model.enterContactSelectionMode()
            }
            .font(.system(size: 12.5, weight: .medium))
            .buttonStyle(.bordered)

            SearchField(text: $model.contactSearchText, prompt: model.l10n(.search))
            .frame(width: 240)

            refreshButton
        }
    }

    private var selectionControls: some View {
        @Bindable var model = model

        return HStack(spacing: 10) {
            Text("\(model.l10n(.selectedContacts)) \(model.selectedContactDeletionCount)")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button(model.l10n(.selectAll)) {
                model.selectAllVisibleContactsForDeletion()
            }
            .font(.system(size: 12.5, weight: .medium))
            .buttonStyle(.bordered)
            .disabled(model.visibleContactCount == 0 || model.isDeletingContacts)

            Button(role: .destructive) {
                isConfirmingDeletion = true
            } label: {
                Label(model.l10n(.deleteContacts), systemImage: "trash")
            }
            .font(.system(size: 12.5, weight: .semibold))
            .buttonStyle(.bordered)
            .disabled(model.selectedContactDeletionCount == 0 || model.isDeletingContacts)

            Button(model.l10n(.cancel)) {
                model.exitContactSelectionMode()
            }
            .font(.system(size: 12.5, weight: .medium))
            .buttonStyle(.bordered)
            .disabled(model.isDeletingContacts)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await model.refreshContacts() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 15, height: 15)
                .rotationEffect(.degrees(model.isLoading && !reduceMotion ? 360 : 0))
                .animation(
                    model.isLoading && !reduceMotion
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : nil,
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
        case .ungrouped: Image(systemName: "person.crop.circle.badge.questionmark")
        }
    }

    private var iconColor: Color {
        switch collection.kind {
        case .all: ContactsNativeStyle.accent
        case .container: Color(hex: 0x8E8E93)
        case .group: Color(hex: 0xFF9500)
        case .ungrouped: Color(hex: 0x8E8E93)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let row: ContactListRowModel
    let isSelected: Bool
    let isSelectionMode: Bool
    let isMarkedForDeletion: Bool
    let action: () -> Void

    var body: some View {
        let rowIsSelected = isSelectionMode ? isMarkedForDeletion : isSelected

        Button(action: action) {
            HStack(spacing: 10) {
                AvatarView(
                    name: row.displayName,
                    color: row.kind.map(color(for:)) ?? Color(hex: 0x8E8E93),
                    size: 34
                )
                .overlay(alignment: .bottomTrailing) {
                    if isSelectionMode {
                        ContactSelectionMark(isSelected: isMarkedForDeletion)
                            .offset(x: 3, y: 3)
                            .transition(selectionMarkTransition)
                    }
                }

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
                            .foregroundStyle(rowIsSelected ? .white.opacity(0.75) : .secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if let text = row.daysUntilText, let days = row.daysUntil {
                    Text(text)
                        .font(.system(size: 11, weight: days <= 7 ? .semibold : .regular))
                        .foregroundStyle(days <= 7 ? ContactsNativeStyle.red : (rowIsSelected ? .white.opacity(0.75) : Color.secondary.opacity(0.75)))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .foregroundStyle(rowIsSelected ? .white : .primary)
            .background(rowIsSelected ? ContactsNativeStyle.accent : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.displayName)
        .accessibilityAddTraits(rowIsSelected ? .isSelected : [])
        .animation(BirthdayTheme.Motion.allowed(BirthdayTheme.Motion.quickFade, reduceMotion: reduceMotion), value: isSelectionMode)
        .animation(BirthdayTheme.Motion.allowed(BirthdayTheme.Motion.press, reduceMotion: reduceMotion), value: isMarkedForDeletion)
    }

    private var selectionMarkTransition: AnyTransition {
        if reduceMotion {
            .opacity
        } else {
            .scale(scale: 0.92).combined(with: .opacity)
        }
    }
}

private struct ContactSelectionMark: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 15, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(isSelected ? ContactsNativeStyle.accent : Color.secondary.opacity(0.75), Color.white)
            .background(Color.white, in: Circle())
            .shadow(color: .black.opacity(0.10), radius: 1, y: 0.5)
            .accessibilityHidden(true)
    }
}

// MARK: - Detail

struct BulkContactSelectionView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var isConfirmingDeletion = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.circle.badge.minus")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(ContactsNativeStyle.red)

            VStack(spacing: 6) {
                Text(model.l10n(.deleteContacts))
                    .font(.system(size: 22, weight: .bold))
                Text("\(model.l10n(.selectedContacts)) \(model.selectedContactDeletionCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(model.l10n(.deleteContactsMessage))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 420)

            HStack(spacing: 10) {
                Button(model.l10n(.selectAll)) {
                    model.selectAllVisibleContactsForDeletion()
                }
                .buttonStyle(KimiActionButtonStyle(kind: .regular))
                .disabled(model.visibleContactCount == 0 || model.isDeletingContacts)

                Button(role: .destructive) {
                    isConfirmingDeletion = true
                } label: {
                    Label(model.l10n(.deleteContacts), systemImage: "trash")
                }
                .buttonStyle(KimiActionButtonStyle(kind: .regular))
                .disabled(model.selectedContactDeletionCount == 0 || model.isDeletingContacts)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ContactsNativeStyle.detailBackground(colorScheme))
        .alert(model.l10n(.deleteContactsTitle), isPresented: $isConfirmingDeletion) {
            Button(model.l10n(.deleteContacts), role: .destructive) {
                Task { await model.deleteSelectedContacts() }
            }
            Button(model.l10n(.cancel), role: .cancel) { }
        } message: {
            Text(model.l10n(.deleteContactsMessage))
        }
    }
}

struct ContactBirthdayEditor: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

                editableCards

                actionBar
            }
            .padding(.horizontal, 32)
            .padding(.top, 34)
            .padding(.bottom, 60)
            .frame(maxWidth: 624)
            .frame(maxWidth: .infinity)
        }
        .background(ContactsNativeStyle.detailBackground(colorScheme))
    }

    @ViewBuilder
    private var editableCards: some View {
        Group {
            if isEditing {
                editCards
            } else {
                readCards
            }
        }
        .transition(editableCardsTransition)
        .animation(BirthdayTheme.Motion.allowed(BirthdayTheme.Motion.quickFade, reduceMotion: reduceMotion), value: isEditing)
    }

    private var editableCardsTransition: AnyTransition {
        if reduceMotion {
            .opacity
        } else {
            .asymmetric(
                insertion: .scale(scale: 0.985, anchor: .top).combined(with: .opacity),
                removal: .opacity
            )
        }
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
                if profile.records.isEmpty {
                    Text(model.l10n(.noBirthdays))
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    ForEach(Array(profile.records.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            NativeDivider()
                        }
                        BirthdayRecordSummaryRow(record: record)
                    }
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
                if draft.entries.isEmpty {
                    Text(model.l10n(.noBirthdays))
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    ForEach(Array($draft.entries.enumerated()), id: \.element.id) { index, $entry in
                        if index > 0 {
                            NativeDivider()
                        }
                        BirthdayEditEntryView(entry: $entry, profile: profile) {
                            draft.removeEntry(id: entry.id)
                        }
                    }
                }
            }

            Button {
                draft.addEntry(personID: profile.id, kind: .gregorian)
            } label: {
                Label(model.l10n(.addBirthday), systemImage: "plus.circle.fill")
            }
            .buttonStyle(KimiActionButtonStyle(kind: .regular))

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
                .disabled(draft.payload(personID: profile.id) == nil || isSaving)

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
        guard let payload = draft.payload(personID: profile.id) else { return }
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

struct BirthdayRecordSummaryRow: View {
    @Environment(BirthdayAppModel.self) private var model
    let record: BirthdayRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StaticKindBadge(kind: record.kind, title: shortKindName(record.kind, model: model))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.formatter.calendarName(record.kind, locale: model.language.coreLocale))
                        .font(.system(size: 13, weight: .semibold))
                    Text(sourceText)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(model.formatter.originalDate(record, locale: model.language.coreLocale))
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Text(thisYearText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sourceText: String {
        record.source == .local ? model.l10n(.localOnly) : model.l10n(.appleSynced)
    }

    private var thisYearText: String {
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        guard let date = model.resolver.occurrence(for: record, inGregorianYear: year) else {
            return model.l10n(.notFilled)
        }
        let dateText = model.formatter.occurrenceDate(date, locale: model.language.coreLocale)
        guard let age = model.resolver.age(for: record, on: date) else {
            return "\(model.l10n(.thisYearDate)) \(dateText)"
        }
        return "\(model.l10n(.thisYearDate)) \(dateText) · \(ageText(age))"
    }

    private func ageText(_ age: Int) -> String {
        switch model.language.coreLocale {
        case .english: "Turns \(age)"
        case .simplifiedChinese: "满 \(age) 岁"
        case .traditionalChinese: "滿 \(age) 歲"
        }
    }
}

struct BirthdayEditEntryView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Binding var entry: BirthdayEditEntry
    let profile: ContactBirthdayProfile
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker(model.l10n(.calendarKind), selection: $entry.kind) {
                    ForEach(BirthdayCalendarKind.allCases) { kind in
                        Text(model.formatter.calendarName(kind, locale: model.language.coreLocale)).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 220, alignment: .leading)

                Text(sourceText)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help(model.l10n(.deleteBirthday))
                .accessibilityLabel(model.l10n(.deleteBirthday))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            NativeDivider()

            NativeInfoRow(label: model.l10n(.birthDate)) {
                ViewThatFits(in: .horizontal) {
                    birthdayDateControls

                    VStack(alignment: .leading, spacing: 8) {
                        birthdayDateFields
                        leapMonthToggle
                    }
                }
            }

            NativeDivider()

            NativeInfoRow(label: model.l10n(.thisYearDate)) {
                Text(thisYearText)
                    .foregroundStyle(thisYearText == model.l10n(.notFilled) ? .tertiary : .primary)
            }
        }
    }

    private var sourceText: String {
        entry.source == .local ? model.l10n(.localOnly) : model.l10n(.appleSynced)
    }

    private var birthdayDateControls: some View {
        HStack(spacing: 8) {
            birthdayDateFields
            leapMonthToggle
        }
    }

    private var birthdayDateFields: some View {
        HStack(spacing: 8) {
            NativeDateField("YYYY", text: $entry.year, width: 72)
            NativeDateField("MM", text: $entry.month, width: 58)
            NativeDateField("DD", text: $entry.day, width: 58)
        }
    }

    @ViewBuilder
    private var leapMonthToggle: some View {
        if entry.kind == .chinese {
            Toggle(model.l10n(.leapMonth), isOn: $entry.isLeapMonth)
                .toggleStyle(.switch)
                .font(.system(size: 12))
        }
    }

    private var thisYearText: String {
        guard let spec = entry.dateSpec(personID: profile.id) else {
            return model.l10n(.notFilled)
        }
        let record = BirthdayRecord(person: profile.person, dateSpec: spec)
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        guard let date = model.resolver.occurrence(for: record, inGregorianYear: year) else {
            return model.l10n(.notFilled)
        }
        let dateText = model.formatter.occurrenceDate(date, locale: model.language.coreLocale)
        guard let age = model.resolver.age(for: record, on: date) else {
            return dateText
        }
        return "\(dateText) · \(ageText(age))"
    }

    private func ageText(_ age: Int) -> String {
        switch model.language.coreLocale {
        case .english: "Turns \(age)"
        case .simplifiedChinese: "满 \(age) 岁"
        case .traditionalChinese: "滿 \(age) 歲"
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(BirthdayTheme.Motion.allowed(BirthdayTheme.Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
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
            .animation(BirthdayTheme.Motion.hover, value: isHovering)
    }
}

private extension View {
    func fixedContactColumn(width: CGFloat, priority: Double) -> some View {
        frame(minWidth: width, idealWidth: width, maxWidth: width)
            .layoutPriority(priority)
            .clipped()
    }

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

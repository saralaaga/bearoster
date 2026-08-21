import RosterCore
import Foundation
import SwiftUI

// MARK: - Permissions & settings

struct PermissionsSettingsView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                permissionSection
                if permissionIsGranted {
                    contactGroupAccessSection
                        .transition(settingsSectionTransition)
                }
                preferencesSection
                contactFieldsSection
                voiceSection
                supportedCalendarsSection
                dataSourceSection
                aboutSection
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 32)
            .frame(maxWidth: SettingsLayout.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(RosterTheme.windowBackground(colorScheme))
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion), value: permissionIsGranted)
    }

    private var permissionSection: some View {
        SettingsSection(title: model.l10n(.contacts)) {
            PermissionAccessPanel()
        }
    }

    private var permissionIsGranted: Bool {
        model.permissionState == .authorized || model.permissionState == .limited
    }

    private var contactGroupAccessSection: some View {
        @Bindable var model = model

        return SettingsSection(title: model.l10n(.contactGroupAccess)) {
            VStack(spacing: 0) {
                SettingsRow(
                    title: model.l10n(.contactGroupAccess),
                    detail: ""
                ) {
                    Picker(model.l10n(.contactGroupAccess), selection: Binding(
                        get: { model.contactAccessScope.mode },
                        set: { model.setContactAccessMode($0) }
                    )) {
                        Text(model.l10n(.allContactsAccess)).tag(ContactAccessScope.Mode.allContacts)
                        Text(model.l10n(.selectedGroupsAccess)).tag(ContactAccessScope.Mode.selectedGroups)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }

                if model.contactAccessScope.mode == .selectedGroups {
                    SettingsDivider()
                    ContactGroupAccessEditor()
                        .transition(settingsSectionTransition)
                }
            }
            .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion), value: model.contactAccessScope.mode)
        }
    }

    private var settingsSectionTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: -4))
    }

    private var preferencesSection: some View {
        @Bindable var model = model

        return SettingsSection(title: model.l10n(.settings)) {
            VStack(spacing: 0) {
                SettingsRow(
                    title: model.l10n(.appLanguage),
                    detail: languageDisplayName
                ) {
                    Picker(model.l10n(.appLanguage), selection: $model.language) {
                        Text("System").tag(AppLanguage.system)
                        Text("简体中文").tag(AppLanguage.zhHans)
                        Text("繁體中文").tag(AppLanguage.zhHant)
                        Text("English").tag(AppLanguage.en)
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                SettingsDivider()

                SettingsRow(title: model.l10n(.displayAge), detail: model.l10n(.age)) {
                    Toggle("", isOn: $model.showAge)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingsDivider()

                SettingsRow(title: model.l10n(.upcoming), detail: upcomingRangeDisplay) {
                    Stepper("", value: $model.upcomingRange, in: 7...120, step: 7)
                        .labelsHidden()
                        .monospacedDigit()
                }
            }
        }
    }

    private var contactFieldsSection: some View {
        @Bindable var model = model

        return SettingsSection(title: model.l10n(.contactFieldAccess)) {
            VStack(spacing: 0) {
                SettingsRow(
                    title: model.l10n(.extendedContactFields),
                    detail: model.extendedContactFieldsEnabled ? model.l10n(.extendedContactFieldsEnabled) : model.l10n(.basicContactFields)
                ) {
                    Toggle("", isOn: Binding(
                        get: { model.extendedContactFieldsEnabled },
                        set: { model.extendedContactFieldsEnabled = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .frame(width: 64, alignment: .trailing)
                }

                SettingsDivider()

                Text(model.l10n(.extendedContactFieldsBody))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(RosterTheme.inkSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
        }
    }

    private var voiceSection: some View {
        @Bindable var model = model

        return SettingsSection(title: model.l10n(.voiceInput)) {
            VStack(alignment: .leading, spacing: 12) {
                TextField(model.l10n(.voicePlaceholder), text: $model.voiceText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RosterTheme.controlBackground(colorScheme), in: RoundedRectangle(cornerRadius: RosterTheme.controlCorner))
                    .overlay(
                        RoundedRectangle(cornerRadius: RosterTheme.controlCorner)
                            .strokeBorder(RosterTheme.separator(colorScheme))
                    )

                HStack(spacing: 10) {
                    Button {
                        Task { await model.toggleVoiceInput() }
                    } label: {
                        Label(
                            model.isListening ? model.l10n(.stopListening) : model.l10n(.startListening),
                            systemImage: model.isListening ? "stop.circle" : "mic"
                        )
                    }
                    .buttonStyle(SettingsActionButtonStyle(kind: .regular))

                    Button(model.l10n(.convertDate)) {
                        model.convertVoiceText()
                    }
                    .buttonStyle(SettingsActionButtonStyle(kind: .primary))

                    Spacer(minLength: 0)
                }

                if let result = model.voiceResult {
                    Text(result)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(RosterTheme.inkSecondary)
                        .transition(.opacity)
                }

                if model.isListening {
                    Label(model.l10n(.listening), systemImage: "waveform")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RosterTheme.accent)
                        .transition(.opacity)
                }
            }
            .padding(18)
            .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.voiceResult)
            .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.isListening)
        }
    }

    private var supportedCalendarsSection: some View {
        SettingsSection(title: model.l10n(.supportedCalendars)) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(RosterCalendarKind.allCases) { kind in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color(for: kind))
                            .frame(width: 9, height: 9)
                        Text(model.formatter.calendarName(kind, locale: model.language.coreLocale))
                            .font(.system(size: 13, weight: .semibold))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RosterTheme.hoverFill(colorScheme), in: RoundedRectangle(cornerRadius: RosterTheme.controlCorner))
                }
            }
            .padding(18)
        }
    }

    private var dataSourceSection: some View {
        SettingsSection(title: model.l10n(.dataSource)) {
            SettingsRow(title: model.l10n(.contactsSource), detail: model.l10n(.permissionBody)) {
                Image(systemName: "checkmark.icloud.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(RosterTheme.accent)
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: model.l10n(.about)) {
            Text(model.l10n(.aboutBody))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(RosterTheme.inkSecondary)
                .lineSpacing(3)
                .padding(18)
        }
    }

}

private struct PermissionAccessPanel: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    private var isGranted: Bool {
        model.permissionState == .authorized || model.permissionState == .limited
    }

    private var needsSettings: Bool {
        model.permissionState == .denied || model.permissionState == .restricted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                statusIcon

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(isGranted ? model.l10n(.permissionGranted) : model.l10n(.needContacts))
                            .font(.system(size: 15, weight: .semibold))
                        SettingsStatusPill(
                            title: isGranted ? model.l10n(.permissionGranted) : model.l10n(.needContacts),
                            color: isGranted ? RosterTheme.brandSecondary : RosterTheme.mustard
                        )
                    }

                    Text(model.l10n(.permissionBody))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(RosterTheme.inkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if needsSettings {
                        Text(model.l10n(.permissionDenied))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                            .padding(.top, 2)
                    }
                }
                .layoutPriority(1)
            }

            HStack(spacing: 10) {
                if !isGranted && !needsSettings {
                    Button(model.l10n(.allowContacts)) {
                        Task { await model.requestContactsAccess() }
                    }
                    .buttonStyle(SettingsActionButtonStyle(kind: .primary))
                }

                Button(model.l10n(.openSettings)) {
                    model.openContactsSettings()
                }
                .buttonStyle(SettingsActionButtonStyle(kind: isGranted ? .regular : .secondary))

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.l10n(.version))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RosterTheme.inkSecondary)
                    Text(versionDisplay)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            }
        }
        .padding(18)
        .background(RosterTheme.cardBackground(colorScheme))
    }

    private var versionDisplay: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "?"
        return "\(shortVersion) (\(buildNumber))"
    }

    private var statusIcon: some View {
        Image(systemName: isGranted ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(isGranted ? RosterTheme.brandSecondary : RosterTheme.accent)
            .frame(width: 38, height: 38)
            .background(statusBackground, in: Circle())
            .accessibilityHidden(true)
    }

    private var statusBackground: Color {
        isGranted ? RosterTheme.brandSecondary.opacity(0.12) : RosterTheme.accent.opacity(0.12)
    }
}

private struct ContactGroupAccessEditor: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.l10n(.contactGroupAccessBody))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(RosterTheme.inkSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(summaryText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(RosterTheme.inkSecondary)
                    .monospacedDigit()

                Spacer(minLength: 12)

                Button(model.l10n(.selectAll)) {
                    model.selectAllContactAccessGroups()
                }
                .buttonStyle(SettingsActionButtonStyle(kind: .secondary))

                Button(model.l10n(.clearSelection)) {
                    model.clearContactAccessGroups()
                }
                .buttonStyle(SettingsActionButtonStyle(kind: .secondary))
            }

            if model.contactGrouping.groups.isEmpty && ungroupedContactCount == 0 {
                Text(model.l10n(.noContactGroups))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(RosterTheme.inkSecondary)
                    .padding(.vertical, 4)
            } else {
                groupRows
            }
        }
        .padding(18)
    }

    @ViewBuilder
    private var groupRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            if ungroupedContactCount > 0 {
                ContactGroupAccessRow(
                    title: model.l10n(.ungroupedContacts),
                    count: ungroupedContactCount,
                    isOn: Binding(
                        get: { model.contactAccessScope.includeUngroupedContacts },
                        set: { model.setIncludeUngroupedContacts($0) }
                    )
                )
            }

            ForEach(containerGroups, id: \.container.id) { section in
                VStack(alignment: .leading, spacing: 7) {
                    Text(section.container.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    VStack(spacing: 0) {
                        ForEach(Array(section.groups.enumerated()), id: \.element.id) { index, group in
                            if index > 0 {
                                RosterTheme.separator(colorScheme)
                                    .frame(height: 0.5)
                                    .padding(.leading, 26)
                            }
                            ContactGroupAccessRow(
                                title: group.name,
                                count: group.contactCount,
                                isOn: Binding(
                                    get: { model.contactAccessScope.allowedGroupIDs.contains(group.id) },
                                    set: { model.setContactAccessGroup(group.id, isAllowed: $0) }
                                )
                            )
                        }
                    }
                    .background(RosterTheme.hoverFill(colorScheme), in: RoundedRectangle(cornerRadius: RosterTheme.controlCorner))
                }
            }
        }
    }

    private var containerGroups: [(container: ContactContainerSummary, groups: [ContactGroupSummary])] {
        model.contactGrouping.containers
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .compactMap { container in
                let groups = model.contactGrouping.groups
                    .filter { $0.containerID == container.id }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                guard !groups.isEmpty else { return nil }
                return (container, groups)
            }
    }

    private var ungroupedContactCount: Int {
        model.contactGrouping.contactIDsByCollectionID[ContactCollectionIdentifier.ungrouped]?.count ?? 0
    }

    private var summaryText: String {
        let groupCount = model.contactAccessScope.allowedGroupIDs.count
        let contactCount = selectedContactCount
        switch model.language.coreLocale {
        case .english:
            return "\(model.l10n(.selectedGroupsSummary)): \(groupCount), \(contactCount) contacts"
        case .simplifiedChinese:
            return "\(model.l10n(.selectedGroupsSummary)) \(groupCount) 个，包含 \(contactCount) 位联系人"
        case .traditionalChinese:
            return "\(model.l10n(.selectedGroupsSummary)) \(groupCount) 個，包含 \(contactCount) 位聯絡人"
        }
    }

    private var selectedContactCount: Int {
        model.contactAccessScope.allowedContactIDs(in: model.contactGrouping)?.count ?? model.profiles.count
    }
}

private struct ContactGroupAccessRow: View {
    let title: String
    let count: Int
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(count)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct SettingsSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                content
            }
            .background(RosterTheme.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(RosterTheme.separator(colorScheme))
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.13 : 0.035), radius: 9, y: 2)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.018), radius: 2, y: 1)
        }
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.primary)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RosterTheme.inkSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            accessory
                .frame(
                    alignment: .trailing
                )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum SettingsLayout {
    static let contentWidth: CGFloat = 860
}

private struct SettingsDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RosterTheme.separator(colorScheme)
            .frame(height: 0.5)
            .padding(.leading, 18)
    }
}

private struct SettingsStatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private enum SettingsActionButtonKind {
    case primary
    case regular
    case secondary
}

private struct SettingsActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let kind: SettingsActionButtonKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: kind == .primary ? .semibold : .medium))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .frame(minWidth: kind == .primary ? 116 : 96)
            .background(background(configuration: configuration), in: RoundedRectangle(cornerRadius: RosterTheme.controlCorner))
            .overlay(
                RoundedRectangle(cornerRadius: RosterTheme.controlCorner)
                    .strokeBorder(border)
            )
            .opacity(isEnabled ? 1 : 0.52)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: .white
        case .regular, .secondary: .primary
        }
    }

    private var border: Color {
        switch kind {
        case .primary: .clear
        case .regular: RosterTheme.separator(colorScheme)
        case .secondary: RosterTheme.separator(colorScheme)
        }
    }

    private func background(configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            return configuration.isPressed ? Color(hex: 0x0062CC) : RosterTheme.accent
        case .regular:
            return configuration.isPressed ? RosterTheme.hoverFill(colorScheme) : RosterTheme.controlBackground(colorScheme)
        case .secondary:
            return configuration.isPressed ? RosterTheme.hoverFill(colorScheme) : Color.clear
        }
    }
}

private extension PermissionsSettingsView {
    var languageDisplayName: String {
        switch model.language {
        case .system: return "System"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        }
    }

    var upcomingRangeDisplay: String {
        switch model.language.coreLocale {
        case .english:
            return "\(model.upcomingRange) days"
        case .simplifiedChinese:
            return "\(model.upcomingRange) 天"
        case .traditionalChinese:
            return "\(model.upcomingRange) 天"
        }
    }
}

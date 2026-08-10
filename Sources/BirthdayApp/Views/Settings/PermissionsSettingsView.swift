import BirthdayCore
import SwiftUI

// MARK: - Permissions & settings

struct PermissionsSettingsView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                permissionSection
                preferencesSection
                contactFieldsSection
                voiceSection
                supportedCalendarsSection
                dataSourceSection
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 32)
            .frame(maxWidth: SettingsLayout.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(BirthdayTheme.windowBackground(colorScheme))
    }

    private var permissionSection: some View {
        SettingsSection(title: model.l10n(.contacts)) {
            PermissionAccessPanel()
        }
    }

    private var preferencesSection: some View {
        @Bindable var model = model

        return SettingsSection(title: model.l10n(.settings)) {
            VStack(spacing: 0) {
                SettingsRow(
                    title: model.l10n(.appLanguage),
                    detail: "System / 简体中文 / 繁體中文 / English"
                ) {
                    Picker(model.l10n(.appLanguage), selection: $model.language) {
                        Text("System").tag(AppLanguage.system)
                        Text("简体中文").tag(AppLanguage.zhHans)
                        Text("繁體中文").tag(AppLanguage.zhHant)
                        Text("English").tag(AppLanguage.en)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 360)
                }

                SettingsDivider()

                SettingsRow(title: model.l10n(.displayAge), detail: model.l10n(.age)) {
                    Toggle("", isOn: $model.showAge)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .frame(width: 64, alignment: .trailing)
                }

                SettingsDivider()

                SettingsRow(title: model.l10n(.upcoming), detail: "\(model.upcomingRange)d") {
                    Stepper("\(model.upcomingRange)d", value: $model.upcomingRange, in: 7...120, step: 7)
                        .monospacedDigit()
                        .frame(width: 150, alignment: .trailing)
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
                    .foregroundStyle(BirthdayTheme.inkSecondary)
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
                HStack(spacing: 10) {
                    TextField(model.l10n(.voicePlaceholder), text: $model.voiceText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(BirthdayTheme.controlBackground(colorScheme), in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner))
                        .overlay(
                            RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner)
                                .strokeBorder(BirthdayTheme.separator(colorScheme))
                        )

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
                }

                if let result = model.voiceResult {
                    Text(result)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(BirthdayTheme.inkSecondary)
                        .transition(.opacity)
                }

                if model.isListening {
                    Label(model.l10n(.listening), systemImage: "waveform")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BirthdayTheme.accent)
                        .transition(.opacity)
                }
            }
            .padding(18)
            .animation(BirthdayTheme.Motion.allowed(BirthdayTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.voiceResult)
            .animation(BirthdayTheme.Motion.allowed(BirthdayTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.isListening)
        }
    }

    private var supportedCalendarsSection: some View {
        SettingsSection(title: model.l10n(.supportedCalendars)) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(BirthdayCalendarKind.allCases) { kind in
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
                    .background(BirthdayTheme.hoverFill(colorScheme), in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner))
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
                    .foregroundStyle(BirthdayTheme.accent)
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }
}

private struct PermissionAccessPanel: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    private var isGranted: Bool {
        model.permissionState == .authorized || model.permissionState == .limited
    }

    private var needsSettings: Bool {
        model.permissionState == .denied || model.permissionState == .restricted
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: isGranted ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isGranted ? BirthdayTheme.brandSecondary : BirthdayTheme.accent)
                .frame(width: 38, height: 38)
                .background(statusBackground, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(isGranted ? model.l10n(.permissionGranted) : model.l10n(.needContacts))
                        .font(.system(size: 15, weight: .semibold))
                    SettingsStatusPill(
                        title: isGranted ? model.l10n(.permissionGranted) : model.l10n(.needContacts),
                        color: isGranted ? BirthdayTheme.brandSecondary : BirthdayTheme.mustard
                    )
                }

                Text(model.l10n(.permissionBody))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(BirthdayTheme.inkSecondary)
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

            VStack(alignment: .trailing, spacing: 8) {
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
            }
            .frame(minWidth: 156, alignment: .trailing)
        }
        .padding(18)
        .background(BirthdayTheme.cardBackground(colorScheme))
    }

    private var statusBackground: Color {
        isGranted ? BirthdayTheme.brandSecondary.opacity(0.12) : BirthdayTheme.accent.opacity(0.12)
    }
}

private struct SettingsSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                content
            }
            .background(BirthdayTheme.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(BirthdayTheme.separator(colorScheme))
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.045), radius: 10, y: 3)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.10 : 0.025), radius: 2, y: 1)
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
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BirthdayTheme.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            accessory
                .frame(
                    minWidth: SettingsLayout.accessoryMinWidth,
                    maxWidth: SettingsLayout.accessoryMaxWidth,
                    alignment: .trailing
                )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum SettingsLayout {
    static let contentWidth: CGFloat = 860
    static let accessoryMinWidth: CGFloat = 180
    static let accessoryMaxWidth: CGFloat = 420
}

private struct SettingsDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BirthdayTheme.separator(colorScheme)
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
            .background(background(configuration: configuration), in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner))
            .overlay(
                RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner)
                    .strokeBorder(border)
            )
            .opacity(isEnabled ? 1 : 0.52)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(BirthdayTheme.Motion.allowed(BirthdayTheme.Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
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
        case .regular: BirthdayTheme.separator(colorScheme)
        case .secondary: BirthdayTheme.separator(colorScheme)
        }
    }

    private func background(configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            return configuration.isPressed ? Color(hex: 0x0062CC) : BirthdayTheme.accent
        case .regular:
            return configuration.isPressed ? BirthdayTheme.hoverFill(colorScheme) : BirthdayTheme.controlBackground(colorScheme)
        case .secondary:
            return configuration.isPressed ? BirthdayTheme.hoverFill(colorScheme) : Color.clear
        }
    }
}

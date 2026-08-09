import BirthdayCore
import SwiftUI

// MARK: - Permissions & settings

struct PermissionsSettingsView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            HStack {
                Text(model.l10n(.permissions))
                    .font(.system(size: 19, weight: .black))
                    .tracking(0.4)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)

            Rectangle()
                .fill(BirthdayTheme.separator(colorScheme))
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsCard(title: model.l10n(.contacts)) {
                        permissionHero
                    }

                    settingsCard(title: model.l10n(.settings)) {
                        VStack(spacing: 0) {
                            settingsRow(title: model.l10n(.appLanguage), detail: model.l10n(.calendarKind)) {
                                Picker(model.l10n(.appLanguage), selection: $model.language) {
                                    Text("System").tag(AppLanguage.system)
                                    Text("简体中文").tag(AppLanguage.zhHans)
                                    Text("繁體中文").tag(AppLanguage.zhHant)
                                    Text("English").tag(AppLanguage.en)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 360)
                            }
                            settingsDivider
                            settingsRow(title: model.l10n(.displayAge), detail: model.l10n(.age)) {
                                Toggle("", isOn: $model.showAge)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }
                            settingsDivider
                            settingsRow(title: model.l10n(.upcoming), detail: "\(model.upcomingRange)d") {
                                Stepper("\(model.upcomingRange)d", value: $model.upcomingRange, in: 7...120, step: 7)
                                    .frame(width: 140)
                            }
                        }
                    }

                    settingsCard(title: model.l10n(.voiceInput)) {
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
                                .mcmButtonStyle()
                                Button(model.l10n(.convertDate)) {
                                    model.convertVoiceText()
                                }
                                .font(.system(size: 12.5, weight: .bold))
                                .mcmButtonStyle()
                            }
                            if let result = model.voiceResult {
                                Text(result)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(BirthdayTheme.inkSecondary)
                            }
                            if model.isListening {
                                Text(model.l10n(.listening))
                                    .font(.caption)
                                    .foregroundStyle(BirthdayTheme.inkSecondary)
                            }
                        }
                    }

                    settingsCard(title: model.l10n(.supportedCalendars)) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                            ForEach(BirthdayCalendarKind.allCases) { kind in
                                HStack(spacing: 8) {
                                    Circle().fill(color(for: kind)).frame(width: 9, height: 9)
                                    Text(model.formatter.calendarName(kind, locale: model.language.coreLocale))
                                        .font(.system(size: 13, weight: .bold))
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(BirthdayTheme.hoverFill(colorScheme), in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner))
                            }
                        }
                    }

                    settingsCard(title: model.l10n(.dataSource)) {
                        Text(model.l10n(.contactsSource))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(BirthdayTheme.inkSecondary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: BirthdayTheme.Layout.contentMaxWidth, alignment: .leading)
            }
        }
        .background(BirthdayTheme.windowBackground(colorScheme))
    }

    @ViewBuilder
    private var permissionHero: some View {
        if model.permissionState == .authorized {
            VStack(alignment: .leading, spacing: 10) {
                Label(model.l10n(.permissionGranted), systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(BirthdayTheme.olive)
                Text(model.l10n(.permissionBody))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(BirthdayTheme.inkSecondary)
                    .lineSpacing(3)
                Button(model.l10n(.openSettings)) {
                    model.openContactsSettings()
                }
                .font(.system(size: 12.5, weight: .bold))
                .mcmButtonStyle()
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text(model.l10n(.needContacts))
                    .font(.system(size: 15, weight: .black))
                Text(model.l10n(.permissionBody))
                    .foregroundStyle(BirthdayTheme.inkSecondary)
                    .lineSpacing(3)

                HStack {
                    Button(model.l10n(.allowContacts)) {
                        Task { await model.requestContactsAccess() }
                    }
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(BirthdayTheme.accent, in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner))

                    Button(model.l10n(.openSettings)) {
                        model.openContactsSettings()
                    }
                    .font(.system(size: 12.5, weight: .bold))
                    .mcmButtonStyle()
                }

                if model.permissionState == .denied || model.permissionState == .restricted {
                    Text(model.l10n(.permissionDenied))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(BirthdayTheme.separator(colorScheme))
            .frame(height: 1)
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            MCMStripes()
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .tracking(0.8)
                    .textCase(.uppercase)
                content()
            }
            .padding(18)
        }
        .cardStyle()
    }

    private func settingsRow<Accessory: View>(title: String, detail: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                Text(detail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(BirthdayTheme.inkSecondary)
            }
            Spacer(minLength: 12)
            accessory()
        }
        .padding(.vertical, 10)
    }
}

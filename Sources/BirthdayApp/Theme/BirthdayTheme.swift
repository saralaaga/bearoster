import BirthdayCore
import SwiftUI

// MARK: - Theme

enum BirthdayTheme {
    static let brandPrimary = Color(hex: 0xE8683C)
    static let brandSecondary = Color(hex: 0xF2A65A)
    static let calendarGregorian = Color(hex: 0xE8883C)
    static let calendarLunar = Color(hex: 0xD64541)
    static let calendarHebrew = Color(hex: 0x7D9BA8)
    static let calendarIslamic = Color(hex: 0x4A7C59)
    static let mustard = Color(hex: 0xD4A574)
    static let walnut = Color(hex: 0x6B5D4F)
    static let teak = Color(hex: 0x8B7355)
    static let ink = Color(hex: 0x2C2416)
    static let inkSecondary = Color(hex: 0x594A40)
    static let inkTertiary = Color(hex: 0x6B5D4F)

    static let accent = brandPrimary
    static let olive = calendarIslamic
    static let blue = calendarHebrew
    static let coral = calendarLunar
    static let cardCorner: CGFloat = CornerRadius.md
    static let controlCorner: CGFloat = CornerRadius.sm

    enum Layout {
        static let sidebarWidth: CGFloat = 224
        static let dayDetailWidth: CGFloat = 296
        static let contactListWidth: CGFloat = 260
        static let minWindowWidth: CGFloat = 1100
        static let minWindowHeight: CGFloat = 720
        static let contentMaxWidth: CGFloat = 760
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum CornerRadius {
        static let xs: CGFloat = 5
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let full: CGFloat = 999
    }

    static func pageBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.12, green: 0.09, blue: 0.06) : Color(red: 0.91, green: 0.84, blue: 0.74)
    }

    static func windowBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.17, green: 0.14, blue: 0.09) : Color(red: 0.96, green: 0.90, blue: 0.83)
    }

    static func sidebarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.15, green: 0.12, blue: 0.07) : Color(red: 0.94, green: 0.88, blue: 0.78)
    }

    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.23, green: 0.20, blue: 0.13) : .white
    }

    static func controlBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.27, green: 0.23, blue: 0.16) : .white
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : walnut.opacity(0.22)
    }

    static func selectedFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? brandPrimary.opacity(0.20) : brandPrimary.opacity(0.13)
    }

    static func hoverFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : walnut.opacity(0.07)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(MCMCardStyle())
    }

    func mcmButtonStyle() -> some View {
        buttonStyle(MCMPressButtonStyle())
            .modifier(MCMButtonChrome())
    }
}

private struct MCMCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(BirthdayTheme.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: BirthdayTheme.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: BirthdayTheme.cardCorner)
                    .strokeBorder(BirthdayTheme.separator(colorScheme))
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.07), radius: 9, y: 2)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.04), radius: 18, y: 8)
    }
}

private struct MCMButtonChrome: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isHovering ? BirthdayTheme.hoverFill(colorScheme) : BirthdayTheme.controlBackground(colorScheme),
                in: RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BirthdayTheme.controlCorner)
                    .strokeBorder(BirthdayTheme.separator(colorScheme))
            )
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct MCMPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

func color(for kind: BirthdayCalendarKind) -> Color {
    switch kind {
    case .gregorian: BirthdayTheme.calendarGregorian
    case .chinese: BirthdayTheme.calendarLunar
    case .hebrew: BirthdayTheme.calendarHebrew
    case .islamic: BirthdayTheme.calendarIslamic
    }
}

func daysLeftText(_ days: Int, locale: CalendarFormattingService.AppLocale) -> String {
    switch locale {
    case .english: days == 1 ? "in 1 day" : "in \(days) days"
    case .simplifiedChinese: "\(days) 天后"
    case .traditionalChinese: "\(days) 天後"
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

@MainActor
func shortKindName(_ kind: BirthdayCalendarKind, model: BirthdayAppModel) -> String {
    switch kind {
    case .gregorian: model.formatter.calendarName(kind, locale: model.language.coreLocale)
    case .chinese: model.language.coreLocale == .english ? "Lunar" : model.formatter.calendarName(kind, locale: model.language.coreLocale)
    case .hebrew: "עברי"
    case .islamic: "هجري"
    }
}

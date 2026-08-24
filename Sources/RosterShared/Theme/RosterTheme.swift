import RosterCore
import SwiftUI

// MARK: - Theme

package enum RosterTheme {
    package static let brandPrimary = Color(hex: 0x007AFF)
    package static let brandSecondary = Color(hex: 0x34C759)
    package static let calendarGregorian = Color(hex: 0x007AFF)
    package static let calendarLunar = Color(hex: 0xFF3B30)
    package static let calendarHebrew = Color(hex: 0x5856D6)
    package static let calendarIslamic = Color(hex: 0x34C759)
    package static let mustard = Color(hex: 0xFF9500)
    package static let walnut = Color(hex: 0x8E8E93)
    package static let teak = Color(hex: 0x636366)
    package static let ink = Color.primary
    package static let inkSecondary = Color.secondary
    package static let inkTertiary = Color.secondary.opacity(0.78)

    package static let accent = brandPrimary
    package static let olive = calendarIslamic
    package static let blue = calendarHebrew
    package static let coral = calendarLunar
    package static let cardCorner: CGFloat = CornerRadius.md
    package static let controlCorner: CGFloat = CornerRadius.sm

    package enum Layout {
        package static let sidebarWidth: CGFloat = 224
        package static let sidebarCollapsedWidth: CGFloat = 64
        package static let dayDetailWidth: CGFloat = 296
        package static let contactListWidth: CGFloat = 260
        package static let minWindowWidth: CGFloat = 1100
        package static let minWindowHeight: CGFloat = 720
        package static let contentMaxWidth: CGFloat = 760
    }

    package enum Spacing {
        package static let xs: CGFloat = 4
        package static let sm: CGFloat = 8
        package static let md: CGFloat = 12
        package static let lg: CGFloat = 16
        package static let xl: CGFloat = 24
    }

    package enum CornerRadius {
        package static let xs: CGFloat = 5
        package static let sm: CGFloat = 8
        package static let md: CGFloat = 12
        package static let lg: CGFloat = 16
        package static let full: CGFloat = 999
    }

    package enum Motion {
        package static let press = Animation.easeOut(duration: 0.10)
        package static let hover = Animation.easeOut(duration: 0.12)
        package static let quickFade = Animation.easeOut(duration: 0.14)
        package static let stateChange = Animation.easeOut(duration: 0.16)
        package static let paneSwitch = Animation.easeOut(duration: 0.18)
        package static let sectionReveal = Animation.easeOut(duration: 0.18)
        package static let toastIn = Animation.easeOut(duration: 0.24)
        package static let toastOut = Animation.easeOut(duration: 0.14)

        package static func allowed(_ animation: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : animation
        }
    }

    package static func pageBackground(_ scheme: ColorScheme) -> Color {
        #if os(macOS)
        scheme == .dark ? Color(nsColor: .underPageBackgroundColor) : Color(hex: 0xF5F5F7)
        #else
        scheme == .dark ? Color(hex: 0x000000) : Color(hex: 0xF5F5F7)
        #endif
    }

    package static func windowBackground(_ scheme: ColorScheme) -> Color {
        #if os(macOS)
        scheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color.white
        #else
        scheme == .dark ? Color(hex: 0x000000) : Color.white
        #endif
    }

    package static func sidebarBackground(_ scheme: ColorScheme) -> Color {
        #if os(macOS)
        scheme == .dark ? Color(nsColor: .underPageBackgroundColor) : Color(hex: 0xF2F2F7)
        #else
        scheme == .dark ? Color(hex: 0x1C1C1E) : Color(hex: 0xF2F2F7)
        #endif
    }

    package static func cardBackground(_ scheme: ColorScheme) -> Color {
        #if os(macOS)
        scheme == .dark ? Color(nsColor: .controlBackgroundColor) : .white
        #else
        scheme == .dark ? Color(hex: 0x1C1C1E) : .white
        #endif
    }

    package static func controlBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : .white
    }

    package static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.10)
    }

    package static func selectedFill(_ scheme: ColorScheme) -> Color {
        brandPrimary
    }

    package static func hoverFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06)
    }
}

package extension View {
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

    package func body(content: Content) -> some View {
        content
            .background(RosterTheme.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: RosterTheme.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: RosterTheme.cardCorner)
                    .strokeBorder(RosterTheme.separator(colorScheme))
            )
            // Emil: 双层阴影系统 - 扩散层 + 清晰层
            // 真实物体的阴影有两部分：模糊的环境光遮挡 + 清晰的直接投影
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.15 : 0.04),
                radius: 12,
                y: 4
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.10 : 0.02),
                radius: 2,
                y: 1
            )
    }
}

private struct MCMButtonChrome: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    package func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isHovering ? RosterTheme.hoverFill(colorScheme) : RosterTheme.controlBackground(colorScheme),
                in: RoundedRectangle(cornerRadius: RosterTheme.controlCorner)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RosterTheme.controlCorner)
                    .strokeBorder(RosterTheme.separator(colorScheme))
            )
            .onHover { isHovering = $0 }
            .animation(RosterTheme.Motion.hover, value: isHovering)
    }
}

private struct MCMPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    package func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

package func color(for kind: RosterCalendarKind) -> Color {
    switch kind {
    case .gregorian: RosterTheme.calendarGregorian
    case .chinese: RosterTheme.calendarLunar
    case .hebrew: RosterTheme.calendarHebrew
    case .islamic: RosterTheme.calendarIslamic
    }
}

package func daysLeftText(_ days: Int, locale: CalendarFormattingService.AppLocale) -> String {
    switch locale {
    case .english: days == 1 ? "in 1 day" : "in \(days) days"
    case .simplifiedChinese: "\(days) 天后"
    case .traditionalChinese: "\(days) 天後"
    }
}

package extension Color {
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
package func shortKindName(_ kind: RosterCalendarKind, model: RosterAppModel) -> String {
    switch kind {
    case .gregorian: model.formatter.calendarName(kind, locale: model.language.coreLocale)
    case .chinese: model.language.coreLocale == .english ? "Lunar" : model.formatter.calendarName(kind, locale: model.language.coreLocale)
    case .hebrew: "עברי"
    case .islamic: "هجري"
    }
}

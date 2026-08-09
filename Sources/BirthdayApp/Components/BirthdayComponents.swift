import BirthdayCore
import SwiftUI

// MARK: - Shared components

struct AvatarView: View {
    let name: String
    var color: Color = BirthdayTheme.accent
    var size: CGFloat = 38

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.82), color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            .accessibilityHidden(true)
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count > 1, let first = parts.first?.first, let last = parts.last?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2))
    }
}

struct KindBadge: View {
    @Environment(BirthdayAppModel.self) private var model
    let kind: BirthdayCalendarKind

    var body: some View {
        Text(shortKindName(kind, model: model))
            .font(.system(size: 10, weight: .bold))
            .textCase(.uppercase)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(color(for: kind))
            .background(color(for: kind).opacity(0.18), in: RoundedRectangle(cornerRadius: BirthdayTheme.CornerRadius.xs))
    }
}

struct CountdownChip: View {
    @Environment(BirthdayAppModel.self) private var model
    let days: Int

    var body: some View {
        Text(days == 0 ? model.l10n(.today) : daysLeftText(days, locale: model.language.coreLocale))
            .font(.system(size: 11.5, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(days == 0 ? .white : BirthdayTheme.inkSecondary)
            .background(
                days == 0 ? BirthdayTheme.accent : BirthdayTheme.mustard.opacity(0.42),
                in: RoundedRectangle(cornerRadius: BirthdayTheme.CornerRadius.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BirthdayTheme.CornerRadius.sm)
                    .strokeBorder(days == 0 ? Color.clear : BirthdayTheme.mustard.opacity(0.35))
            )
    }
}

struct MCMStripes: View {
    var body: some View {
        HStack(spacing: 4) {
            BirthdayTheme.accent
            BirthdayTheme.mustard
            BirthdayTheme.olive
        }
        .frame(height: 4)
        .clipShape(Capsule())
    }
}
// MARK: - Toast

struct ToastView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.callout.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.82), in: Capsule())
            .shadow(radius: 12)
    }
}

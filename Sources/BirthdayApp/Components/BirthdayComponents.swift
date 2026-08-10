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
        StaticKindBadge(kind: kind, title: shortKindName(kind, model: model))
    }
}

struct StaticKindBadge: View {
    let kind: BirthdayCalendarKind
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(color(for: kind))
            .background(color(for: kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }
}

struct CountdownChip: View {
    @Environment(BirthdayAppModel.self) private var model
    let days: Int

    var body: some View {
        StaticCountdownChip(days: days, title: days == 0 ? model.l10n(.today) : daysLeftText(days, locale: model.language.coreLocale))
    }
}

struct StaticCountdownChip: View {
    let days: Int
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11.5, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(days == 0 ? .white : .secondary)
            .background(
                days == 0 ? BirthdayTheme.accent : Color.secondary.opacity(0.11),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(days == 0 ? Color.clear : Color.secondary.opacity(0.12))
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

struct CalculationProgressView: View {
    @Environment(BirthdayAppModel.self) private var model
    let progress: BirthdayCalculationProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(model.l10n(.calculatingBirthdays))
                    .font(.system(size: 12.5, weight: .bold))
                Spacer(minLength: 0)
                Text("\(Int(progress.fraction * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BirthdayTheme.inkSecondary)
                    .monospacedDigit()
            }

            if !progress.message.isEmpty {
                Text(progress.message)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(BirthdayTheme.inkSecondary)
                    .lineLimit(1)
            }

            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(width: 260)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.l10n(.calculatingBirthdays))
    }
}

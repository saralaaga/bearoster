import RosterCore
import RosterShared
import SwiftUI

// MARK: - Shared components

struct AvatarView: View {
    let name: String
    var color: Color = RosterTheme.accent
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
    @Environment(RosterAppModel.self) private var model
    let kind: RosterCalendarKind

    var body: some View {
        StaticKindBadge(kind: kind, title: shortKindName(kind, model: model))
    }
}

struct StaticKindBadge: View {
    let kind: RosterCalendarKind
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
    @Environment(RosterAppModel.self) private var model
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
                days == 0 ? RosterTheme.accent : Color.secondary.opacity(0.11),
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
            RosterTheme.accent
            RosterTheme.mustard
            RosterTheme.olive
        }
        .frame(height: 4)
        .clipShape(Capsule())
    }
}

struct ContactTagChip: View {
    let tag: ContactTag
    var isCompact = false

    var body: some View {
        Text(tag.name)
            .font(.system(size: isCompact ? 10.5 : 11, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, isCompact ? 6 : 7)
            .padding(.vertical, isCompact ? 2 : 3)
            .foregroundStyle(Color(hex: tag.color))
            .background(Color(hex: tag.color).opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color(hex: tag.color).opacity(0.16))
            )
    }
}

struct ContactTagSummary: View {
    let tags: [ContactTag]
    var limit = 2
    var isCompact = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(tags.prefix(limit))) { tag in
                ContactTagChip(tag: tag, isCompact: isCompact)
            }
            if tags.count > limit {
                Text("+\(tags.count - limit)")
                    .font(.system(size: isCompact ? 10.5 : 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, isCompact ? 5 : 6)
                    .padding(.vertical, isCompact ? 2 : 3)
                    .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
            }
        }
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
    @Environment(RosterAppModel.self) private var model
    let progress: RosterCalculationProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(model.l10n(.calculatingRosters))
                    .font(.system(size: 12.5, weight: .bold))
                Spacer(minLength: 0)
                Text("\(Int(progress.fraction * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(RosterTheme.inkSecondary)
                    .monospacedDigit()
            }

            if !progress.message.isEmpty {
                Text(progress.message)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(RosterTheme.inkSecondary)
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
        .accessibilityLabel(model.l10n(.calculatingRosters))
    }
}

// MARK: - Adaptive pane width

/// Caps a centered content column at a fraction of the available pane width
/// instead of a fixed point value, so wide windows get wider (but bounded)
/// content columns. Apply outside scroll views.
private struct AdaptivePaneWidthModifier: ViewModifier {
    let floor: CGFloat
    let cap: CGFloat
    var ratio: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .frame(maxWidth: min(cap, max(floor, proxy.size.width * ratio)))
                .frame(maxWidth: .infinity)
        }
    }
}

extension View {
    /// `floor` keeps the column at least as wide as the previous fixed width,
    /// `ratio` grows it with the pane, `cap` bounds the growth for readability.
    func adaptivePaneWidth(floor: CGFloat, cap: CGFloat, ratio: CGFloat = 0.9) -> some View {
        modifier(AdaptivePaneWidthModifier(floor: floor, cap: cap, ratio: ratio))
    }
}

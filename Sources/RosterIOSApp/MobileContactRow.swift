import RosterCore
import RosterShared
import SwiftUI

struct MobileContactRow: View {
    let row: ContactListRowModel
    let tags: [ContactTag]

    var body: some View {
        HStack(spacing: 12) {
            MobileAvatar(name: row.displayName, color: color(for: row.kind ?? .gregorian), size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let daysUntilText = row.daysUntilText, !daysUntilText.isEmpty {
                Text(daysUntilText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
        }
        .frame(minHeight: 50)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if let tag = tags.first {
            return "\(tag.name) · \(row.subtitle)"
        }
        return row.subtitle
    }
}

struct MobileFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(title)  \(count)")
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? RosterTheme.accent : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MobileAvatar: View {
    let name: String
    var color: Color = RosterTheme.accent
    var size: CGFloat = 42

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0) } ?? "?"
    }
}

import RosterCore
import RosterShared
import SwiftUI

struct MobileTagsView: View {
    @Environment(RosterAppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section(model.l10n(.smartGroups)) {
                    tagSummaryRow(title: model.l10n(.allContactsAccess), count: model.contactCount(for: .all), color: RosterTheme.accent)
                    tagSummaryRow(title: model.l10n(.untaggedContacts), count: model.contactCount(for: .untagged), color: .secondary)
                }

                Section(model.l10n(.myTags)) {
                    if model.contactTagTreeNodes.isEmpty {
                        ContentUnavailableView(model.l10n(.noTags), systemImage: "tag")
                    } else {
                        ForEach(model.contactTagTreeNodes) { node in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: node.tag.color))
                                    .frame(width: 10, height: 10)

                                Text(node.tag.name)
                                    .padding(.leading, CGFloat(node.depth) * 14)

                                Spacer()

                                Text("\(model.contactCount(for: .tag(node.tag.id)))")
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .navigationTitle(model.l10n(.tags))
        }
    }

    private func tagSummaryRow(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

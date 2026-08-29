import RosterCore
import RosterShared
import SwiftUI

struct MobileTagsView: View {
    @Environment(RosterAppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section("智能分组") {
                    tagSummaryRow(title: "全部联系人", count: model.contactCount(for: .all), color: RosterTheme.accent)
                    tagSummaryRow(title: "未打标签", count: model.contactCount(for: .untagged), color: .secondary)
                }

                Section("我的标签") {
                    if model.contactTagTreeNodes.isEmpty {
                        ContentUnavailableView("没有标签", systemImage: "tag")
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
            .navigationTitle("标签")
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

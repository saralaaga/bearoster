import RosterCore
import RosterShared
import SwiftUI

struct MobileContactsView: View {
    @Environment(RosterAppModel.self) private var model
    @State private var searchText = ""
    @State private var selectedFilter: ContactTagFilter = .all

    private var rows: [ContactListRowModel] {
        model.contactListSections.flatMap(\.rows).filter { row in
            searchText.isEmpty ||
            row.displayName.localizedCaseInsensitiveContains(searchText) ||
            row.subtitle.localizedCaseInsensitiveContains(searchText) ||
            row.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                filterSection

                if rows.isEmpty {
                    ContentUnavailableView("没有联系人", systemImage: "person.crop.circle")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(rows) { row in
                        NavigationLink(value: row.id) {
                            MobileContactRow(row: row, tags: model.tags(for: row.id))
                        }
                    }
                }
            }
            .navigationTitle("通讯录")
            .searchable(text: $searchText, prompt: "搜索姓名、公司、标签")
            .navigationDestination(for: String.self) { contactID in
                if let profile = model.profile(for: contactID) {
                    MobileContactDetailView(profile: profile)
                } else {
                    ContentUnavailableView("联系人不可用", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
            .toolbar {
                ToolbarItem(placement: addButtonPlacement) {
                    Button { } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新建联系人")
                }
            }
        }
    }

    private var addButtonPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MobileFilterChip(title: "全部", count: model.visibleContactCount, isSelected: selectedFilter == .all) {
                    selectedFilter = .all
                    model.selectTagFilter(.all)
                }

                MobileFilterChip(title: "未打标签", count: model.contactCount(for: .untagged), isSelected: selectedFilter == .untagged) {
                    selectedFilter = .untagged
                    model.selectTagFilter(.untagged)
                }

                ForEach(model.contactTagFilterOptions.compactMap(\.tag).prefix(4)) { tag in
                    MobileFilterChip(title: tag.name, count: model.contactCount(for: .tag(tag.id)), isSelected: selectedFilter == .tag(tag.id)) {
                        selectedFilter = .tag(tag.id)
                        model.selectTagFilter(.tag(tag.id))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

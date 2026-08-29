import RosterShared
import SwiftUI

struct MobileCalendarView: View {
    @Environment(RosterAppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                if model.filteredRecordListGroups.isEmpty {
                    ContentUnavailableView("没有日期", systemImage: "calendar")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(model.filteredRecordListGroups) { group in
                        Section(group.title) {
                            ForEach(group.items) { item in
                                NavigationLink(value: item.contactID) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.contactName)
                                            .font(.body.weight(.semibold))
                                        Text(item.metaText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .accessibilityLabel(item.accessibilityLabel)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("日历")
            .navigationDestination(for: String.self) { contactID in
                if let profile = model.profile(for: contactID) {
                    MobileContactDetailView(profile: profile)
                } else {
                    ContentUnavailableView("联系人不可用", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
        }
    }
}

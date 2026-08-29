import RosterCore
import RosterShared
import SwiftUI

struct MobileContactDetailView: View {
    @Environment(RosterAppModel.self) private var model
    let profile: ContactRosterProfile

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    MobileAvatar(name: profile.displayName, size: 76)

                    Text(profile.displayName)
                        .font(.title2.weight(.bold))

                    if !detailSubtitle.isEmpty {
                        Text(detailSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            if !phoneNumbers.isEmpty {
                Section("电话") {
                    ForEach(phoneNumbers, id: \.self) { phone in
                        LabeledContent("手机", value: phone)
                    }
                }
            }

            Section("生日") {
                if profile.records.isEmpty {
                    Text("没有生日记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(profile.records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.formatter.originalDate(record, locale: model.language.coreLocale))
                            Text(model.formatter.calendarName(record.kind, locale: model.language.coreLocale))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("标签") {
                let tags = model.tags(for: profile.id)
                if tags.isEmpty {
                    Text("未打标签")
                        .foregroundStyle(.secondary)
                } else {
                    FlowPills(tags: tags)
                }
            }

            if let extended = model.extendedProfilesByID[profile.id], extended.hasVisibleFields {
                Section("更多资料") {
                    if !extended.emailAddresses.isEmpty {
                        LabeledContent("邮箱", value: extended.emailAddresses.joined(separator: ", "))
                    }
                    if !extended.departmentName.isEmpty {
                        LabeledContent("部门", value: extended.departmentName)
                    }
                    if !extended.jobTitle.isEmpty {
                        LabeledContent("职位", value: extended.jobTitle)
                    }
                }
            }
        }
        .navigationTitle(profile.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: editButtonPlacement) {
                Button("编辑") { }
            }
        }
    }

    private var phoneNumbers: [String] {
        if !profile.phoneNumbers.isEmpty {
            return profile.phoneNumbers
        }
        return model.extendedProfilesByID[profile.id]?.phoneNumbers ?? []
    }

    private var detailSubtitle: String {
        [profile.organizationName, profile.departmentName, profile.jobTitle]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var editButtonPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}

private struct FlowPills: View {
    let tags: [ContactTag]

    var body: some View {
        ViewThatFits {
            HStack(spacing: 6) { pills }
            VStack(alignment: .leading, spacing: 6) { pills }
        }
    }

    @ViewBuilder private var pills: some View {
        ForEach(tags) { tag in
            Text(tag.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(hex: tag.color))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: tag.color).opacity(0.12), in: Capsule())
        }
    }
}

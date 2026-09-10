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
                Section(model.l10n(.phone)) {
                    ForEach(phoneNumbers, id: \.self) { phone in
                        LabeledContent(model.l10n(.mobilePhone), value: phone)
                    }
                }
            }

            Section(model.l10n(.birthday)) {
                if profile.records.isEmpty {
                    Text(model.l10n(.noRosters))
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

            Section(model.l10n(.tags)) {
                let tags = model.tags(for: profile.id)
                if tags.isEmpty {
                    Text(model.l10n(.untaggedContacts))
                        .foregroundStyle(.secondary)
                } else {
                    FlowPills(tags: tags)
                }
            }

            if let extended = model.extendedProfilesByID[profile.id], extended.hasVisibleFields {
                Section(model.l10n(.moreFields)) {
                    if !extended.emailAddresses.isEmpty {
                        LabeledContent(model.l10n(.email), value: extended.emailAddresses.joined(separator: ", "))
                    }
                    if !extended.departmentName.isEmpty {
                        LabeledContent(model.l10n(.department), value: extended.departmentName)
                    }
                    if !extended.jobTitle.isEmpty {
                        LabeledContent(model.l10n(.jobTitle), value: extended.jobTitle)
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
                Button(model.l10n(.edit)) { }
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

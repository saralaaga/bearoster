import RosterCore
import RosterShared
import SwiftUI

struct TagsView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let selectedProfile = model.selectedProfile

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TagContactsHeader(count: model.visibleTagContactCount, title: title)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(model.contactListSections) { section in
                            Section {
                                ForEach(section.rows) { row in
                                    ContactListRow(
                                        row: row,
                                        isSelected: selectedProfile?.id == row.id,
                                        isSelectionMode: false,
                                        isMarkedForSelection: false
                                    ) {
                                        model.selectedContactID = row.id
                                    }
                                }
                            } header: {
                                ContactSectionHeader(title: section.title)
                            }
                        }
                    }
                }
                .transition(tagListTransition)
                .scrollContentBackground(.hidden)
                .background(RosterTheme.windowBackground(colorScheme))
            }
            .frame(width: 340)
            .overlay(alignment: .trailing) {
                RosterTheme.separator(colorScheme)
                    .frame(width: 0.5)
            }

            ZStack {
                RosterTheme.pageBackground(colorScheme)
                VStack(spacing: 0) {
                    if let selectedProfile {
                        ContactRosterEditor(profile: selectedProfile)
                            .id(selectedProfile.id)
                            .transition(detailTransition)
                    } else {
                        ContentUnavailableView(model.l10n(.tags), systemImage: "tag")
                            .transition(detailTransition)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: selectedProfile?.id)
        }
        .background(RosterTheme.windowBackground(colorScheme))
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.selectedTagsFilter)
    }

    private var tagListTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: 5))
    }

    private var detailTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: 4))
    }

    private var title: String {
        switch model.selectedTagsFilter {
        case .all:
            return model.l10n(.tags)
        case .untagged:
            return model.l10n(.untaggedContacts)
        case let .tag(tagID):
            return model.tagPath(for: tagID)
        }
    }
}

struct TagsToolbar: View {
    @Environment(RosterAppModel.self) private var model
    @State private var isShowingNewTagPopover = false

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 12) {
            Text(model.l10n(.tags))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Button {
                isShowingNewTagPopover = true
            } label: {
                Label(model.l10n(.newTag), systemImage: "plus")
            }
            .font(.system(size: 12.5, weight: .medium))
            .buttonStyle(.bordered)
            .popover(isPresented: $isShowingNewTagPopover, arrowEdge: .bottom) {
                NewTagPopover(parentTagID: nil) {
                    isShowingNewTagPopover = false
                }
            }

            ContactFiltersButton()

            SearchField(text: $model.contactSearchText, prompt: model.l10n(.search))
                .frame(width: 240)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TagContactsHeader: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let count: Int
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
            Text(contactCountText(count, locale: model.language.coreLocale))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            RosterTheme.separator(colorScheme)
                .frame(height: 0.5)
        }
    }
}

struct NewTagPopover: View {
    @Environment(RosterAppModel.self) private var model
    let parentTagID: String?
    let onDone: () -> Void
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.l10n(.newTag))
                .font(.system(size: 14, weight: .semibold))

            TextField(model.l10n(.newTag), text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Button(model.l10n(.cancel)) {
                    onDone()
                }
                .buttonStyle(.bordered)

                Button(model.l10n(.apply)) {
                    apply()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func apply() {
        Task { @MainActor in
            await model.createTag(name: name, parentTagID: parentTagID)
            onDone()
        }
    }
}

private func contactCountText(_ count: Int, locale: CalendarFormattingService.AppLocale) -> String {
    switch locale {
    case .english: count == 1 ? "1 contact" : "\(count) contacts"
    case .simplifiedChinese: "\(count) 位联系人"
    case .traditionalChinese: "\(count) 位聯絡人"
    }
}

# iOS Contacts-First App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first native iOS app slice for Roster: a contacts-first mobile shell backed by shared Roster model/service code.

**Architecture:** Extract platform-neutral app logic from the current macOS executable into a `RosterShared` library target, keep macOS-only AppKit views in `RosterApp`, then add a thin iOS app target/shell with `TabView` and native contacts-first SwiftUI screens. The first slice should compile, preserve current macOS behavior, and show real contacts from `RosterAppModel` where Contacts permission allows it.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, Contacts, Speech, AVFoundation, sqlite3, Swift Testing. No new third-party dependencies.

---

## File Structure

Shared target:

- Create directory: `Sources/RosterShared/`
- Move into `Sources/RosterShared/`:
  - `RosterAppModel.swift`
  - `RosterLocalization.swift`
  - `VoiceInputService.swift`
  - `Theme/RosterTheme.swift`
  - all files in `Services/` except `ContactAssignmentSupport.swift`
- Keep in `Sources/RosterApp/`:
  - `RosterApp.swift`
  - `RosterRootView.swift`
  - `RosterE2EFixtures.swift`
  - `Components/`
  - `Views/`
  - `Services/ContactAssignmentSupport.swift`
- Create iOS shell under `Sources/RosterIOSApp/`:
  - `RosterIOSApp.swift`: `@main` iOS app entry point.
  - `MobileRootView.swift`: four-tab shell.
  - `MobileContactsView.swift`: contacts home list.
  - `MobileContactDetailView.swift`: pushed contact detail.
  - `MobileTagsView.swift`: tag list and smart groups.
  - `MobileCalendarView.swift`: agenda-first calendar surface for v1.
  - `MobileMoreView.swift`: settings/sync/permissions entry points.

Package products:

- Existing macOS executable remains `Roster`.
- New shared library product: `RosterShared`.
- New iOS executable product: `RosterIOS` as a source-level SwiftUI app shell. A polished runnable iOS `.app` still needs an Xcode wrapper after this package slice.

## Task 1: Add iOS Platform And Contacts Limited Authorization

**Files:**
- Modify: `Package.swift`
- Modify: `Sources/RosterCore/ContactsRepository.swift`
- Test: `Tests/RosterCoreTests/RosterCoreTests.swift`

- [ ] **Step 1: Write the failing authorization mapping test**

Add a test-visible helper only under `DEBUG` if needed. Prefer exposing a small internal function in `ContactsRepository` with `@testable` access:

```swift
// Sources/RosterCore/ContactsRepository.swift
#if DEBUG
extension ContactsRepository {
    static func testMapAuthorization(_ status: CNAuthorizationStatus) -> ContactsPermissionState {
        mapAuthorization(status)
    }
}
#endif
```

Then add this test:

```swift
@Test("Contacts authorization handles limited access")
func contactsAuthorizationHandlesLimitedAccess() {
    if #available(macOS 15.0, iOS 18.0, *) {
        #expect(ContactsRepository.testMapAuthorization(.limited) == .authorized)
    }
}
```

- [ ] **Step 2: Run the focused test and confirm it fails or does not compile**

Run:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build" --filter contactsAuthorizationHandlesLimitedAccess
```

Expected before implementation: either `.limited` is missing from the switch or `testMapAuthorization` does not exist.

- [ ] **Step 3: Implement `.limited` support**

Update the switch:

```swift
private static func mapAuthorization(_ status: CNAuthorizationStatus) -> ContactsPermissionState {
    switch status {
    case .notDetermined: return .notDetermined
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    case .limited: return .authorized
    @unknown default: return .unknown
    }
}
```

If the active macOS SDK does not expose `.limited`, guard it:

```swift
if #available(macOS 15.0, iOS 18.0, *), status == .limited {
    return .authorized
}
```

Then keep the existing switch for older SDK cases.

- [ ] **Step 4: Add iOS platform declaration**

Update `Package.swift`:

```swift
platforms: [
    .macOS(.v14),
    .iOS(.v17)
],
```

- [ ] **Step 5: Verify**

Run:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build" --filter contactsAuthorizationHandlesLimitedAccess
```

Expected: focused test passes.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/RosterCore/ContactsRepository.swift Tests/RosterCoreTests/RosterCoreTests.swift
git commit -m "Prepare contacts authorization for iOS"
```

## Task 2: Extract `RosterShared` Target

**Files:**
- Modify: `Package.swift`
- Move: listed shared files from `Sources/RosterApp/` to `Sources/RosterShared/`
- Modify: moved `Sources/RosterShared/RosterAppModel.swift`
- Modify: moved `Sources/RosterShared/Theme/RosterTheme.swift`
- Modify: `Sources/RosterApp/RosterApp.swift`
- Modify: `Sources/RosterApp/RosterRootView.swift`
- Modify: every macOS view importing shared symbols if needed
- Test: `Tests/RosterAppTests/RosterAppTests.swift`

- [ ] **Step 1: Move shared files with git**

Run:

```bash
mkdir -p Sources/RosterShared/Services Sources/RosterShared/Theme
git mv Sources/RosterApp/RosterAppModel.swift Sources/RosterShared/RosterAppModel.swift
git mv Sources/RosterApp/RosterLocalization.swift Sources/RosterShared/RosterLocalization.swift
git mv Sources/RosterApp/VoiceInputService.swift Sources/RosterShared/VoiceInputService.swift
git mv Sources/RosterApp/Theme/RosterTheme.swift Sources/RosterShared/Theme/RosterTheme.swift
git mv Sources/RosterApp/Services/AppSupportPaths.swift Sources/RosterShared/Services/AppSupportPaths.swift
git mv Sources/RosterApp/Services/ContactListProjectionService.swift Sources/RosterShared/Services/ContactListProjectionService.swift
git mv Sources/RosterApp/Services/ContactOperationJournalStore.swift Sources/RosterShared/Services/ContactOperationJournalStore.swift
git mv Sources/RosterApp/Services/ContactSnapshotCache.swift Sources/RosterShared/Services/ContactSnapshotCache.swift
git mv Sources/RosterApp/Services/ContactSyncService.swift Sources/RosterShared/Services/ContactSyncService.swift
git mv Sources/RosterApp/Services/ContactTagFiltering.swift Sources/RosterShared/Services/ContactTagFiltering.swift
git mv Sources/RosterApp/Services/ContactTagStore.swift Sources/RosterShared/Services/ContactTagStore.swift
git mv Sources/RosterApp/Services/LocalRosterStore.swift Sources/RosterShared/Services/LocalRosterStore.swift
git mv Sources/RosterApp/Services/NameSortKey.swift Sources/RosterShared/Services/NameSortKey.swift
git mv Sources/RosterApp/Services/RosterDerivedDataService.swift Sources/RosterShared/Services/RosterDerivedDataService.swift
git mv Sources/RosterApp/Services/RosterDerivedDataWorker.swift Sources/RosterShared/Services/RosterDerivedDataWorker.swift
```

Do not move `Sources/RosterApp/Services/ContactAssignmentSupport.swift`; it imports AppKit and belongs to macOS drag/drop.

- [ ] **Step 2: Update Package.swift targets**

Use this shape:

```swift
products: [
    .library(name: "RosterCore", targets: ["RosterCore"]),
    .library(name: "RosterShared", targets: ["RosterShared"]),
    .executable(name: "Roster", targets: ["RosterApp"])
],
targets: [
    .target(
        name: "RosterCore",
        linkerSettings: [
            .linkedFramework("Contacts")
        ]
    ),
    .target(
        name: "RosterShared",
        dependencies: ["RosterCore"],
        linkerSettings: [
            .linkedFramework("SwiftUI"),
            .linkedFramework("Speech"),
            .linkedFramework("AVFoundation"),
            .linkedLibrary("sqlite3")
        ]
    ),
    .executableTarget(
        name: "RosterApp",
        dependencies: ["RosterShared"],
        linkerSettings: [
            .linkedFramework("SwiftUI"),
            .linkedFramework("AppKit")
        ]
    ),
    .testTarget(
        name: "RosterCoreTests",
        dependencies: ["RosterCore"]
    ),
    .testTarget(
        name: "RosterAppTests",
        dependencies: ["RosterShared"]
    )
]
```

- [ ] **Step 3: Add imports in macOS files**

Any macOS file that used `RosterAppModel`, `RosterTheme`, `L10n`, `ContactTag`, or services now needs:

```swift
import RosterShared
```

Keep `import RosterCore` where the file directly references core-only types not re-exported.

- [ ] **Step 4: Make shared model platform-safe**

At the top of `Sources/RosterShared/RosterAppModel.swift`, replace the unconditional AppKit import:

```swift
import RosterCore
import AppKit
import Foundation
import Observation
import SwiftUI
```

with:

```swift
import RosterCore
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif
```

Wrap macOS-only APIs:

```swift
#if os(macOS)
func openContactsSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
        NSWorkspace.shared.open(url)
    }
}
#else
func openContactsSettings() {}
#endif
```

Wrap drag/drop provider methods in macOS guards:

```swift
#if os(macOS)
func dragItemProvider(for contactID: String) -> NSItemProvider { ... }
func assignDroppedContacts(from providers: [NSItemProvider], toTagID tagID: String) -> Bool { ... }
func assignDroppedContacts(from providers: [NSItemProvider], toGroupID groupID: String) -> Bool { ... }
#endif
```

- [ ] **Step 5: Make theme platform-safe**

In `Sources/RosterShared/Theme/RosterTheme.swift`, replace AppKit-only color constructors:

```swift
static func pageBackground(_ scheme: ColorScheme) -> Color {
    #if os(macOS)
    return scheme == .dark ? Color(nsColor: .underPageBackgroundColor) : Color(hex: 0xF5F5F7)
    #else
    return Color(.systemGroupedBackground)
    #endif
}
```

Apply the same pattern to `windowBackground`, `sidebarBackground`, and `cardBackground`, using UIKit semantic colors inside `#else`:

```swift
Color(.systemBackground)
Color(.secondarySystemGroupedBackground)
```

- [ ] **Step 6: Verify macOS still builds**

Run:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build"
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/RosterApp Sources/RosterShared Tests/RosterAppTests
git commit -m "Extract shared Roster app layer"
```

## Task 3: Add iOS App Shell Target

**Files:**
- Modify: `Package.swift`
- Create: `Sources/RosterIOSApp/RosterIOSApp.swift`
- Create: `Sources/RosterIOSApp/MobileRootView.swift`

- [ ] **Step 1: Add iOS executable target to Package.swift**

Add product:

```swift
.executable(name: "RosterIOS", targets: ["RosterIOSApp"])
```

Add target:

```swift
.executableTarget(
    name: "RosterIOSApp",
    dependencies: ["RosterShared"],
    linkerSettings: [
        .linkedFramework("SwiftUI")
    ]
)
```

- [ ] **Step 2: Create iOS app entry**

Create `Sources/RosterIOSApp/RosterIOSApp.swift`:

```swift
import RosterShared
import SwiftUI

@main
struct RosterIOSApp: App {
    @State private var model = RosterAppModel()

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environment(model)
                .task {
                    await model.refreshContacts()
                }
        }
    }
}
```

- [ ] **Step 3: Create the tab shell**

Create `Sources/RosterIOSApp/MobileRootView.swift`:

```swift
import RosterShared
import SwiftUI

struct MobileRootView: View {
    enum Tab: Hashable {
        case contacts
        case tags
        case calendar
        case more
    }

    @State private var tab: Tab = .contacts

    var body: some View {
        TabView(selection: $tab) {
            MobileContactsView()
                .tabItem { Label("通讯录", systemImage: "person.crop.circle") }
                .tag(Tab.contacts)

            MobileTagsView()
                .tabItem { Label("标签", systemImage: "tag") }
                .tag(Tab.tags)

            MobileCalendarView()
                .tabItem { Label("日历", systemImage: "calendar") }
                .tag(Tab.calendar)

            MobileMoreView()
                .tabItem { Label("更多", systemImage: "ellipsis.circle") }
                .tag(Tab.more)
        }
    }
}
```

- [ ] **Step 4: Add minimal compile-only views before the real screens land**

Add these at the bottom of `MobileRootView.swift`; later tasks replace them with full files:

```swift
struct MobileContactsView: View { var body: some View { NavigationStack { Text("通讯录").navigationTitle("通讯录") } } }
struct MobileTagsView: View { var body: some View { NavigationStack { Text("标签").navigationTitle("标签") } } }
struct MobileCalendarView: View { var body: some View { NavigationStack { Text("日历").navigationTitle("日历") } } }
struct MobileMoreView: View { var body: some View { NavigationStack { Text("更多").navigationTitle("更多") } } }
```

- [ ] **Step 5: Verify macOS package still tests**

Run:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build"
```

Expected: all macOS tests pass. If SwiftPM attempts to build `RosterIOSApp` for macOS and fails on iOS-only APIs, keep this target SwiftUI-only until the Xcode wrapper task.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/RosterIOSApp
git commit -m "Add iOS contacts-first app shell"
```

## Task 4: Build Contacts Home Screen

**Files:**
- Modify: `Sources/RosterIOSApp/MobileRootView.swift` to remove the compile-only Contacts view
- Create: `Sources/RosterIOSApp/MobileContactsView.swift`
- Create: `Sources/RosterIOSApp/MobileContactRow.swift`

- [ ] **Step 1: Replace the compile-only Contacts view with a real contacts list**

Create `Sources/RosterIOSApp/MobileContactsView.swift`:

```swift
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
            row.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                filterSection
                ForEach(rows) { row in
                    NavigationLink(value: row.contactID) {
                        MobileContactRow(row: row, tags: model.tags(for: row.contactID))
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { } label: { Image(systemName: "plus") }
                        .accessibilityLabel("新建联系人")
                }
            }
        }
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
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}
```

If `RosterAppModel.profile(for:)` does not exist, add this minimal shared helper:

```swift
func profile(for contactID: String) -> ContactRosterProfile? {
    profileByID[contactID]
}
```

- [ ] **Step 2: Create row and chip components**

Create `Sources/RosterIOSApp/MobileContactRow.swift`:

```swift
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
        if let tag = tags.first { return "\(tag.name) · \(row.subtitle)" }
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
```

Create this mobile-local avatar in the same file so the iOS target does not depend on macOS-only components:

```swift
struct MobileAvatar: View {
    let name: String
    var color: Color = RosterTheme.accent
    var size: CGFloat = 42

    var body: some View {
        Text(String(name.prefix(1)).isEmpty ? "?" : String(name.prefix(1)))
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 3: Run build/test**

Run:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build"
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/RosterIOSApp Sources/RosterShared/RosterAppModel.swift
git commit -m "Build mobile contacts home"
```

## Task 5: Build Contact Detail Screen

**Files:**
- Create: `Sources/RosterIOSApp/MobileContactDetailView.swift`

- [ ] **Step 1: Create detail view**

```swift
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
                    Text(detailSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            let phoneNumbers = profile.phoneNumbers.isEmpty
                ? model.extendedProfilesByID[profile.id]?.phoneNumbers ?? []
                : profile.phoneNumbers
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

            let extended = model.extendedProfilesByID[profile.id]
            if let extended, extended.hasVisibleFields {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { }
            }
        }
    }

    private var detailSubtitle: String {
        [profile.organizationName, profile.departmentName, profile.jobTitle]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
```

The property names above match `ContactRosterProfile` and `ContactExtendedProfile` in `Sources/RosterCore/ContactModels.swift` and `Sources/RosterCore/RosterModels.swift`.

- [ ] **Step 2: Add local pill helpers**

```swift
private struct FlowPills: View {
    let tags: [ContactTag]

    var body: some View {
        ViewThatFits {
            HStack { pills }
            VStack(alignment: .leading) { pills }
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
```

`ContactTag.color` is a `UInt`, matching the existing `Color(hex:)` helper.

- [ ] **Step 3: Verify**

Run:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build"
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/RosterIOSApp/MobileContactDetailView.swift
git commit -m "Add mobile contact detail screen"
```

## Task 6: Build Tags, Calendar, And More V1 Screens

**Files:**
- Create: `Sources/RosterIOSApp/MobileTagsView.swift`
- Create: `Sources/RosterIOSApp/MobileCalendarView.swift`
- Create: `Sources/RosterIOSApp/MobileMoreView.swift`

- [ ] **Step 1: Implement Tags v1**

```swift
import RosterShared
import SwiftUI

struct MobileTagsView: View {
    @Environment(RosterAppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section("智能分组") {
                    NavigationLink("未打标签", value: ContactTagFilter.untagged)
                    NavigationLink("全部联系人", value: ContactTagFilter.all)
                }
                Section("我的标签") {
                    ForEach(model.contactTagTreeNodes) { node in
                        HStack {
                            Circle()
                                .fill(Color(hex: node.tag.color))
                                .frame(width: 10, height: 10)
                            Text(node.tag.name)
                                .padding(.leading, CGFloat(node.depth) * 14)
                            Spacer()
                            Text("\(model.contactCount(for: .tag(node.tag.id)))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("标签")
        }
    }
}
```

- [ ] **Step 2: Implement Calendar v1**

```swift
import RosterShared
import SwiftUI

struct MobileCalendarView: View {
    @Environment(RosterAppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.filteredRecordListGroups) { group in
                    Section(group.title) {
                        ForEach(group.items) { item in
                            NavigationLink(value: item.contactID) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.contactName).font(.body.weight(.semibold))
                                    Text(item.metaText).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("日历")
        }
    }
}
```

This is an agenda-first v1. A month grid can be added after the shell is stable.

- [ ] **Step 3: Implement More v1**

```swift
import RosterShared
import SwiftUI

struct MobileMoreView: View {
    @Environment(RosterAppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section("同步") {
                    LabeledContent("待写回", value: "\(model.pendingContactOperationCount)")
                    LabeledContent("失败", value: "\(model.failedContactOperationCount)")
                    LabeledContent("冲突", value: "\(model.conflictedContactOperationCount)")
                }
                Section("设置") {
                    Toggle("显示年龄", isOn: Binding(
                        get: { model.showAge },
                        set: { model.showAge = $0 }
                    ))
                    Picker("语言", selection: Binding(
                        get: { model.language },
                        set: { model.language = $0 }
                    )) {
                        Text("简体中文").tag(AppLanguage.simplifiedChinese)
                        Text("繁體中文").tag(AppLanguage.traditionalChinese)
                        Text("English").tag(AppLanguage.english)
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}
```

- [ ] **Step 4: Verify and commit**

Run:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build"
```

Expected: all tests pass.

Commit:

```bash
git add Sources/RosterIOSApp
git commit -m "Add mobile secondary tabs"
```

## Task 7: Local Package Verification

**Files:**
- Modify: `Packaging/VERSION` via script

- [ ] **Step 1: Run local package update**

Run:

```bash
scripts/update-local-package.sh
```

Expected: release build succeeds and installs `/Applications/Roster.app`. This validates the existing macOS app was not broken by shared-target extraction.

- [ ] **Step 2: Run all tests**

Run:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build"
```

Expected: all tests pass.

- [ ] **Step 3: Commit build number**

```bash
git add Packaging/VERSION
git commit -m "Bump local package after iOS app foundation"
```

## Task 8: Xcode iOS Wrapper Decision Gate

**Files:**
- No source edits before decision.

- [ ] **Step 1: Present status**

Report:

- `RosterShared` exists and macOS tests pass.
- `RosterIOSApp` source shell exists.
- SwiftPM still cannot produce a polished iOS `.app` bundle with entitlements and Info.plist UX.

- [ ] **Step 2: Ask for wrapper approval**

Ask:

```text
Do you want me to create an Xcode iOS app wrapper now, or keep the iOS UI as a package source target until the shared layer stabilizes?
```

Recommended answer: create the wrapper after Task 7, using `xcode-project-setup` skill.

## Self-Review

Spec coverage:

- Contacts-first tab order is covered by Tasks 3 and 4.
- Contact detail is covered by Task 5.
- Tags and smart groups are covered by Task 6.
- Calendar is included as a v1 agenda tab in Task 6; month grid is intentionally deferred.
- More/settings/sync counts are covered by Task 6.
- Shared implementation boundary is covered by Task 2.
- iOS Contacts limited access is covered by Task 1.
- Local package verification is covered by Task 7.

Known deliberate deferrals:

- CloudKit/cross-device sync.
- Widgets/watch.
- Dedicated iPad split-view pass.
- Full edit forms and PhotosPicker avatar editing.
- Voice input in v1.

These match the approved spec's deferred scope.

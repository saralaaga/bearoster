# Roster iOS Contacts-First Design

## Status

Prototype approved as the mobile design direction. This spec captures the product and UI design for a native iPhone-first Roster app where contact management is the primary job. The source prototype is `.superpowers/brainstorm/43701-1787574350/content/mobile-contacts-first-v2.html`.

## Design Read

Roster mobile is a personal contact-management app with birthday and tag intelligence, not a birthday-only app. The mobile UI should feel native to iOS: calm, dense, editable, and trustworthy. It should use standard Apple navigation, lists, sheets, and forms instead of shrinking the current macOS sidebar and three-column layout.

## Product Positioning

The primary object is the contact. Birthdays, tags, notes, sync status, and cleanup tasks are attributes or workflows around contacts.

The first screen is `通讯录`, not `即将到来`. Upcoming birthdays still matter, but they appear as row badges, contact detail fields, calendar entries, and optional reminder surfaces. This keeps the app focused on managing a real address book.

## Top-Level Navigation

Use an iPhone-first `TabView` with four tabs:

1. `通讯录`: default tab and home screen.
2. `标签`: tag hierarchy, smart groups, and contact cleanup entry points.
3. `日历`: birthday calendar and agenda views.
4. `更多`: sync history, permissions, settings, language, write-back policy, and about.

The tab order is intentionally contacts-first. `更多` absorbs settings and sync/history so the tab bar remains within four items.

On iPad, the same IA can adapt to `NavigationSplitView`, but iPad is not the first implementation target for this spec.

## Screen 1: Contacts Home

The Contacts tab opens to a native large-title list:

- Large title: `通讯录`.
- Trailing `+` button for creating or importing a contact.
- `.searchable` search across name, company, phone, notes, and tags.
- Horizontal filter chips below search: `全部`, high-value tags, and smart filters like `未打标签`.
- Sectioned contact list using native grouped list behavior.
- Each row shows avatar, name, compact metadata, and optional state badges.
- Birthday countdown is a row badge, for example `8 天后`, not the dominant page structure.
- A right-side alphabetical index is acceptable for large contact sets.

Rows should be touch-first: minimum 44 pt hit area, target row height around 56 pt, with semantic text styles. Selection pushes contact detail through `NavigationStack`.

## Screen 2: Contact Detail

Contact detail is a pushed screen from Contacts, Tags, Calendar, or search results.

The header uses standard iOS contact detail structure:

- Back button to the source list.
- `编辑` action in the navigation bar.
- Avatar, display name, and compact subtitle such as city, company, or primary tag.
- Quick actions: phone, message, reminder, tags.

Content uses inset grouped sections:

- Phone and communication fields.
- Birthday records, including calendar kind and write-back state.
- Tags as compact pills.
- Notes and local-only roster metadata.
- Sync/write-back status where relevant.

Birthday data must be framed as contact data. If a birthday is written back to Apple Contacts, the UI should say so explicitly. If data is local-only, that boundary should also be visible.

## Screen 3: Tag Management

The Tags tab has two groups:

- Smart groups: `未打标签`, `缺少生日`, `本月生日`, and sync/conflict states if needed.
- User tags: hierarchical tags with counts and color dots.

Tapping any smart group or tag opens a filtered contact list, then contact detail. Creating a nested tag supports slash-separated input, matching the current macOS behavior: `汽车四班/2024 届` creates or resolves the parent and child tag path.

Tag CRUD should use native iOS interactions:

- Swipe actions for rename/delete where safe.
- Context menus for secondary actions.
- Sheets for create, rename, recolor, and batch assignment.
- No drag-and-drop as the primary workflow on iPhone.

## Screen 4: Cleanup Sheet

Batch cleanup is a modal task, not a new top-level screen.

From `未打标签`, `缺少生日`, or a filtered contact list, the user can open a sheet that shows:

- Task title and count.
- Selectable contact rows.
- Suggested labels or actions.
- Clear write boundary text, such as `仅写入标签关联，不改动 Apple 通讯录分组`.
- Bottom action buttons with selected count, for example `添加标签（1）`.

The sheet can be dismissed without leaving the contacts context. It should support medium and large detents where appropriate.

## Calendar Role

The Calendar tab is a secondary browsing surface:

- Month view with birthday indicators.
- Day selection reveals a list under the grid or pushes an agenda list.
- Tapping an occurrence pushes contact detail.
- Calendar filters should stay minimal: calendar kind and tag filter are enough for v1.

Upcoming birthday logic is still useful but should live inside Calendar, contact rows, detail pages, and optional widgets later.

## More Tab

The More tab collects lower-frequency and sensitive workflows:

- Sync and history.
- Pending, failed, and conflicted contact write-back operations.
- Permissions for Contacts, Speech, microphone, and notifications.
- Write-back policy.
- Language and display preferences.
- About and diagnostics.

Conflicts or failed write-back operations can show a badge on More.

## Interaction Rules

Use native SwiftUI/iOS primitives wherever possible:

- `TabView` for top-level navigation.
- `NavigationStack` for list-detail-edit flows.
- `List` with inset grouped styling for lists and detail sections.
- `.searchable` for search.
- `.sheet` with detents for filters, tag assignment, and cleanup tasks.
- `Form` for editing contact fields.
- `PhotosPicker` for avatar selection.
- Swipe actions for common row operations.
- Context menus for secondary row/tag actions.

Avoid macOS-only interaction assumptions:

- No persistent sidebar on iPhone.
- No hover-only affordances.
- No drag-and-drop as the only way to assign tags.
- No popover-only workflows.
- No fixed-width columns.

## Visual Language

The app should feel like a serious iOS utility:

- System background: grouped gray surfaces with white inset groups.
- Accent: iOS blue for primary actions and selected state.
- Secondary colors only for semantic tags, warnings, and countdown badges.
- Dense but calm rows, not decorative cards.
- Standard iOS rounded list groups and sheet presentation.
- No marketing-style hero sections, oversized empty cards, generic gradients, or decorative visual noise.

Typography should use Dynamic Type-compatible semantic styles, not fixed desktop font sizes.

## Accessibility

The mobile implementation must preserve and improve existing accessibility behavior:

- All rows and controls must have at least 44 pt hit targets.
- Contact rows should combine name, tag, birthday status, and warning state into a useful VoiceOver label.
- Tag color must never be the only state indicator.
- Reduce Motion should disable nonessential transitions.
- Dynamic Type should not clip names, badges, or buttons.
- Sheets must have explicit Cancel/Done actions where dismissal could lose edits.

## Data And Safety

Roster already has a conservative write-back model. Mobile should keep that principle visible:

- Local-only data should be labeled when it will not write to Apple Contacts.
- Any Apple Contacts write-back should be previewable or clearly confirmed.
- iOS Contacts limited-access mode must be supported.
- Sync/history should remain easy to inspect from More.

Cross-device sync is not included in v1. Without CloudKit or another sync layer, iOS and macOS data are separate local stores.

## Implementation Boundary

The design implies a native iOS target, not Mac Catalyst as the primary route.

Smallest technical path:

1. Keep `RosterCore` as shared domain logic.
2. Add iOS platform support where safe.
3. Extract platform-neutral app services, localization, theme tokens, derived-data workers, and model logic into a shared library target such as `RosterShared`.
4. Keep macOS-only AppKit entry points and desktop views in the macOS target.
5. Add an iOS app shell with contacts-first `TabView` and dedicated mobile views.
6. Re-point service/model tests to the shared target.

Known platform fixes include `CNAuthorizationStatus.limited`, iOS-safe theme colors, `PhotosPicker` for avatars, and replacing macOS popovers/drag flows with sheets and list actions.

SwiftPM alone is not enough for a polished iOS app bundle and entitlements. Use an Xcode iOS app wrapper around the shared package when implementation begins.

## V1 Scope

Included in v1 design:

- Contacts-first tab architecture.
- Contact list, detail, and edit flow.
- Tag hierarchy and filtered contact lists.
- Slash-separated nested tag creation.
- Birthday display and edit inside contact detail.
- Calendar browsing as a secondary tab.
- More tab for permissions and sync history.
- Sheet-based tag assignment and cleanup flows.

Deferred from v1:

- Cross-device sync.
- Widgets and watch surfaces.
- iPad-specific split-view optimization beyond basic adaptive behavior.
- Drag-and-drop as a primary workflow.
- Voice input unless implementation cost remains low after the shared target split.

## Open Decisions Before Implementation Plan

1. Minimum iOS version. Recommendation: iOS 17 or newer.
2. Whether v1 supports full Contacts write-back or starts with read-only plus local edits.
3. Whether voice input is included in v1.
4. Whether cleanup smart groups should be limited to `未打标签` and `缺少生日` at first.
5. Whether iPad gets only basic adaptive layouts in v1 or a dedicated split-view pass.

## Prototype Reference

Visual companion prototype:

- `.superpowers/brainstorm/43701-1787574350/content/mobile-contacts-first-v2.html`

The prototype is a design artifact only. SwiftUI implementation should use native components rather than translating the HTML/CSS directly.

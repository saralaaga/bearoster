# Contact Group Access Requirements

## Goal

After the user grants macOS Contacts permission, Roster should let the user choose which Contacts groups are included in the app. Contacts outside the selected groups should not appear in Contacts, birthday list, calendar, upcoming, search, edit, or delete workflows.

## Important Constraint

macOS Contacts permission is app-wide. Apple does not provide a system permission prompt that grants access to only specific groups. Group access in Roster is therefore an app-level allowlist:

- The system grants or denies Contacts access for the whole app.
- Roster stores the user's selected group scope locally.
- Roster should fetch and process only contacts inside the selected scope whenever possible.
- If a broad fetch is temporarily needed to build metadata, non-selected contacts must not be projected into app models, UI, birthday calculations, caches, or editing actions.

## User Experience

Show a new settings section after Contacts permission is authorized:

Title: `通讯录分组访问`

Default mode:

- `全部通讯录`: current behavior. All groups and ungrouped contacts are included.
- `仅选择的分组`: user chooses allowed groups.

When `仅选择的分组` is active:

- Show groups grouped by Apple container/account, such as iCloud, On My Mac, Exchange.
- Each group row has a checkbox/switch, group name, and contact count.
- Include an `未分组联系人` option, because some contacts may not belong to any group.
- Provide `全选` and `清空` actions.
- Show a short summary, for example `已选择 3 个分组，包含 128 位联系人`.

## Data Model

Add a persisted local access scope:

```swift
struct ContactAccessScope: Codable, Hashable, Sendable {
    enum Mode: String, Codable, Sendable {
        case allContacts
        case selectedGroups
    }

    var mode: Mode
    var allowedGroupIDs: Set<String>
    var includeUngroupedContacts: Bool
}
```

This should live in the app's local settings/cache layer, not in Apple Contacts.

## Sync Behavior

The access scope must be applied as early as possible:

- Fetch containers and groups after system authorization.
- Build group/contact ID mappings.
- If mode is `selectedGroups`, fetch contacts with `CNContact.predicateForContactsInGroup(withIdentifier:)` for selected groups where possible.
- Include ungrouped contacts only when `includeUngroupedContacts == true`.
- Deduplicate contacts that belong to multiple selected groups.
- If a selected group is deleted or renamed in Apple Contacts, keep stable behavior:
  - deleted group: remove it from the selected scope and show a non-blocking notice;
  - renamed group: preserve selection by group identifier.

## Projection Rules

The selected scope must affect every derived surface:

- Contacts sidebar group list
- Contact list
- Roster records
- Calendar month cells
- Upcoming birthdays
- Search results
- Local birthday records joined to Apple contacts
- Bulk delete selection
- Extended contact fields

This should not be UI-only filtering. The filtered contact set should be the source input for `RosterDerivedDataService` and `ContactListProjectionService`.

## Editing And Deleting

- Editing is allowed only for contacts inside the active access scope.
- Bulk delete can select and delete only visible scoped contacts.
- If a contact moves out of the allowed groups while selected, clear selection and remove it from visible projections on next sync.

## Caching

The local SQLite/contact cache should include the access scope in cache invalidation:

- Changing scope invalidates derived birthday projections.
- Basic contact snapshots should not expose non-selected contacts to the app model.
- Extended field snapshots should be scoped the same way as basic snapshots.

## Acceptance Criteria

- With `全部通讯录`, behavior matches today's app.
- With `仅选择的分组`, only selected groups appear across Contacts, list, calendar, upcoming, and search.
- A contact in multiple groups appears once if any selected group includes it.
- Ungrouped contacts appear only when `includeUngroupedContacts` is enabled.
- Changing group selection updates all views without restarting the app.
- Re-launch preserves the selected scope.
- Losing Contacts permission hides group access controls and clears visible contact data.

## Suggested Tests

- `ContactAccessScope` persists and restores selected group IDs.
- Projection filters contacts by selected group IDs before birthday derivation.
- Multiple selected groups deduplicate shared contacts.
- Ungrouped contacts obey `includeUngroupedContacts`.
- Deleted group IDs are pruned without crashing.
- Bulk delete only includes visible scoped contacts.

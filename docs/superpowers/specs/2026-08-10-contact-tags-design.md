# Contact Tags Design

## Purpose

Roster needs first-party contact tags that are independent from Apple Contacts groups. Tags help users organize contacts and filter birthday records without writing metadata back to macOS Contacts.

This design replaces the earlier idea of showing tags as a sub-mode inside the Contacts view. Tags are a top-level management surface, visible in the main sidebar alongside Contacts.

## User-Facing Information Architecture

Main sidebar:

```text
Browse
- Calendar
- Rosters

Manage
- Contacts
- Tags
  - Family
    - Parents
    - Relatives
  - Friends
  - Work
    - Clients
    - Coworkers
  - Untagged

Settings
- Permissions
```

Contacts remains the Apple Contacts-oriented area. It shows Apple Contacts data, Apple groups, and contact details. Tags is a peer feature under Manage, not a child tab inside Contacts.

## Tag Model

Tags are local Roster metadata.

Each tag has:

- `id`
- `name`
- `color`
- `parentTagID`
- `sortOrder`
- `createdAt`
- `updatedAt`

Assignments connect contacts to tags:

- `contactID`
- `tagID`
- `createdAt`

Contacts may have multiple tags. Tags may be nested to form a tree. A contact can be assigned to a parent tag, a child tag, or both.

## Filtering Semantics

Selecting a leaf tag shows contacts directly assigned to that tag.

Selecting a parent tag shows contacts assigned to the parent tag and contacts assigned to any descendant tag. For example, selecting `Family` includes contacts tagged `Family`, `Family / Parents`, and `Family / Relatives`.

Selecting `Untagged` shows contacts with no Roster tag assignments.

Roster list tag filtering uses the same descendant-inclusive semantics. The birthday list filter remains local to the birthday list view; selecting a tag in the sidebar does not silently alter the birthday list unless the user is in the Tags surface.

## Main Sidebar Behavior

The main sidebar shows `Tags` as a top-level item in the Manage section.

Behavior:

- Clicking `Tags` opens the Tags surface.
- Tags can expand and collapse in the sidebar.
- Clicking a specific tag opens the Tags surface filtered to that tag.
- The selected tag row is highlighted like other sidebar rows.
- Tag counts include descendant contacts for parent tags.
- `Untagged` is shown as a special filter row.

The sidebar does not show inline delete buttons. It stays primarily navigational.

## Tag Context Menu

Specific tag rows support a context menu.

The menu opens at the user's right-click location, not at a fixed row edge.

Menu actions:

- Rename
- Change color
- New child tag
- Delete tag

`Delete tag` does not delete immediately. It opens a confirmation dialog.

## Delete Confirmation

Deleting a tag is a global operation and requires a modal confirmation.

The confirmation explains:

- The tag will be deleted.
- Contact-tag assignments for that tag will be removed.
- If the tag has child tags, those child tags and their assignments will also be deleted.
- Contacts are not deleted.
- Roster records are not deleted.
- Apple Contacts is not modified.

Only after confirmation does deletion execute.

## Contact Detail Editing

Contact detail and edit views include a Tags property.

The user can:

- Add an existing tag to the contact.
- Create a new tag and add it to the contact.
- Remove a tag from the contact.

Removing a tag from a contact only deletes that contact-tag assignment. It does not delete the global tag.

The edit surface should make this distinction clear by using lightweight chips with remove controls for contact-level removal, while global tag deletion remains in the sidebar context menu plus confirmation dialog.

## Bulk Tagging

Contacts selection mode supports bulk tag assignment.

Rules:

- The existing Select All action is hidden or removed.
- Selected contacts can receive one or more tags.
- Bulk tagging appends tags.
- Bulk tagging does not replace all tags.
- Bulk tagging does not remove tags.
- Existing assignments are ignored without error.

## Roster List

Roster list rows render contact tags next to contact names.

The birthday list toolbar includes a tag filter:

- All
- Untagged
- Specific tags

Specific tag filtering uses descendant-inclusive semantics for parent tags.

## Persistence

Tags are stored in Roster's local SQLite database. They are not written to `CNContact.note` or any Apple Contacts field.

Deleting Apple Contacts contacts removes local assignments for those contact identifiers, but does not delete global tags.

## Acceptance Criteria

- Main sidebar shows Tags as a peer of Contacts.
- Tags can be nested and expanded/collapsed.
- Clicking a parent tag shows contacts from that parent and all descendant tags.
- Clicking a child tag shows contacts assigned to that child and its descendants.
- Clicking Untagged shows contacts with no tag assignments.
- Specific tag rows have a context menu at the right-click location.
- Delete tag opens a confirmation dialog before deleting.
- Deleting a tag removes that tag, descendant tags, and assignments, without deleting contacts, birthdays, or Apple Contacts data.
- Contact detail/edit view exposes a tags editing property.
- A single contact can add existing tags, create a new tag, and remove assigned tags.
- Contact-level tag removal does not delete the global tag.
- Contacts selection mode has no Select All action.
- Bulk tagging appends tags to selected contacts.
- Roster list rows show contact tags.
- Roster list supports tag filtering with descendant-inclusive parent tags.

## Out Of Scope

- Syncing tags across devices.
- Writing tags to Apple Contacts.
- Importing tags from Apple Contacts notes.
- Advanced boolean tag filters.
- Drag-and-drop tree reordering in the first pass.
- Bulk tag removal or replacement.

## Testing

Focused tests should cover:

- SQLite tag persistence, parent-child relationships, assignments, and deletion cascades.
- Descendant-inclusive filtering for parent tags.
- Untagged filtering.
- Roster list tag filtering.
- Contact projection includes tag chips.
- Delete tag does not delete contacts or birthday records.
- Bulk append ignores duplicate assignments.

Manual verification should cover:

- Main sidebar hierarchy and selection behavior.
- Right-click menu position.
- Delete confirmation copy and behavior.
- Contact detail tag editing.
- Local release build opens with the updated navigation.

# Contact Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build local hierarchical contact tags as a top-level Tags feature, with sidebar tag navigation, contact tag editing, delete confirmation, birthday-list filtering, and local release output.

**Architecture:** Keep tags as local SQLite-backed Roster metadata. `RosterCore` owns the portable tag model; `RosterApp` owns persistence, tree/filter helpers, app state, and SwiftUI surfaces. Reuse the existing Contacts three-column layout for the Tags surface where practical, but remove tags as a Contacts sub-mode.

**Tech Stack:** Swift 6, SwiftUI, Observation, SQLite3, Swift Testing, Swift Package Manager.

**Status:** Implemented and locally released on 2026-08-10.

**Verification:**
- `swift test --scratch-path "$PWD/.build"` passed with 30 tests.
- `scripts/build-app.sh release` generated `dist/Roster.app` and `dist/Roster-0.2.0.zip`.
- The rebuilt app was launched from `dist/Roster.app`.

---

## File Map

- Modify `Sources/RosterCore/ContactModels.swift`: add hierarchical tag fields.
- Modify `Sources/RosterApp/Services/ContactTagStore.swift`: migrate schema, persist parent IDs, delete tag subtrees, and assignment operations.
- Modify `Sources/RosterApp/Services/ContactTagFiltering.swift`: support descendant-inclusive tag filters and sidebar tree node state.
- Modify `Sources/RosterApp/RosterAppModel.swift`: add top-level Tags selection state, tag tree helpers, CRUD actions, delete confirmation helpers, and descendant-inclusive filtering.
- Modify `Sources/RosterApp/Views/Sidebar/SidebarView.swift`: render Tags as a peer of Contacts with expandable nested tag rows and context menus.
- Modify `Sources/RosterApp/RootView.swift`: route `.tags` to a Tags view and remove Contacts-internal tag mode assumptions.
- Modify `Sources/RosterApp/Views/Contacts/ContactsEditorView.swift`: remove Apple Groups / Tags segmented control, add clear contact tag editing, keep bulk add tags, hide Select All.
- Create `Sources/RosterApp/Views/Tags/TagsView.swift`: show selected tag contacts and detail using the existing contact row/detail components.
- Modify `Sources/RosterApp/Services/ContactListProjectionService.swift`: remove Contacts-internal tag sidebar mode and keep row tag chips/search support.
- Modify `Sources/RosterApp/Services/RosterDerivedDataService.swift`: filter birthday list by tag descendant sets.
- Modify `Sources/RosterApp/Services/RosterDerivedDataWorker.swift`: cache by tag filter and descendant assignment signature.
- Modify `Sources/RosterApp/Localization.swift`: add strings for top-level tags, delete confirmation, context menu actions, and nested tags.
- Modify `Tests/RosterAppTests/ContactArchitectureTests.swift`: cover hierarchy, descendant filtering, store deletion, and no Select All assumptions where testable.

## Task 1: Hierarchical Tag Model And Store

**Files:**
- Modify: `Sources/RosterCore/ContactModels.swift`
- Modify: `Sources/RosterApp/Services/ContactTagStore.swift`
- Test: `Tests/RosterAppTests/ContactArchitectureTests.swift`

- [x] Add `parentTagID: String?` to `ContactTag` and preserve defaults for existing call sites.
- [x] Add `parent_tag_id` column creation and migration.
- [x] Persist `parentTagID` in load/save.
- [x] Add `deleteTags(tagIDs:)` that deletes selected tag IDs and assignment rows.
- [x] Write tests for parent-child persistence and deletion removing assignments.
- [x] Run `swift test --filter ContactArchitectureTests`.

## Task 2: Tag Tree And Filter Semantics

**Files:**
- Modify: `Sources/RosterApp/Services/ContactTagFiltering.swift`
- Modify: `Sources/RosterApp/RosterAppModel.swift`
- Modify: `Sources/RosterApp/Services/RosterDerivedDataService.swift`
- Modify: `Sources/RosterApp/Services/RosterDerivedDataWorker.swift`
- Test: `Tests/RosterAppTests/ContactArchitectureTests.swift`

- [x] Add tree helpers that return descendants for a tag.
- [x] Make parent tag filtering match assignments for parent plus all descendants.
- [x] Make parent tag counts include descendants.
- [x] Keep `Untagged` as contacts with no assignments.
- [x] Add tests for parent filtering and birthday-list filtering.
- [x] Run `swift test --filter ContactArchitectureTests`.

## Task 3: Top-Level Tags Navigation

**Files:**
- Modify: `Sources/RosterApp/RosterAppModel.swift`
- Modify: `Sources/RosterApp/Views/Sidebar/SidebarView.swift`
- Modify: `Sources/RosterApp/RootView.swift`
- Create: `Sources/RosterApp/Views/Tags/TagsView.swift`

- [x] Add `SidebarSelection.tags`.
- [x] Add selected tag filter state for the Tags surface.
- [x] Render Tags under Manage as a peer of Contacts.
- [x] Render nested tag child rows with expand/collapse.
- [x] Clicking a tag switches to `.tags` and applies that filter.
- [x] Clicking parent Tags opens the Tags management/surface.
- [x] Implement `TagsView` using existing contact list/detail building blocks.
- [x] Build with `swift build`.

## Task 4: Delete Tag Context Menu And Confirmation

**Files:**
- Modify: `Sources/RosterApp/Views/Sidebar/SidebarView.swift`
- Modify: `Sources/RosterApp/RosterAppModel.swift`
- Modify: `Sources/RosterApp/Localization.swift`

- [x] Add context menu actions to concrete tag rows.
- [x] Use SwiftUI context menus so the menu opens at the right-click location.
- [x] Add delete confirmation alert/dialog before deleting.
- [x] Delete selected tag and descendants after confirmation.
- [x] Confirm copy says contacts, birthdays, and Apple Contacts are not deleted.
- [x] Build with `swift build`.

## Task 5: Contact Editing And Bulk Tagging

**Files:**
- Modify: `Sources/RosterApp/Views/Contacts/ContactsEditorView.swift`
- Modify: `Sources/RosterApp/RosterAppModel.swift`
- Modify: `Sources/RosterApp/Localization.swift`

- [x] Remove the Contacts view Apple Groups / Tags segmented control.
- [x] Keep Contacts source list Apple-only.
- [x] Add visible Tags row in contact details with editable chips.
- [x] Support adding existing tags, creating a new tag, and removing assignments from the current contact.
- [x] Keep bulk selection tag append.
- [x] Ensure Select All controls are not visible.
- [x] Build with `swift build`.

## Task 6: Verification And Release

**Files:**
- Modify tests as needed.
- Build output: `dist/Roster.app`, `dist/Roster-0.2.0.zip`

- [x] Run `swift test --scratch-path "$PWD/.build"`.
- [x] Run `scripts/build-app.sh release`.
- [x] Confirm `dist/Roster.app/Contents/MacOS/Roster` timestamp updates.
- [x] Summarize changed files, simplifications, verification, and remaining risks.

## Self-Review

- Spec coverage: every acceptance criterion from `docs/superpowers/specs/2026-08-10-contact-tags-design.md` maps to Tasks 1-6.
- Placeholder scan: no TBD/TODO placeholders.
- Type consistency: `ContactTag.parentTagID`, `ContactTagFilter`, `SidebarSelection.tags`, and `ContactTagStore` names match current project naming.

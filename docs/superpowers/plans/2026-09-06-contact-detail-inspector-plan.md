# Contact Detail Inspector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the macOS contact detail card stack with the approved Apple-native Inspector layout and inline edit flow.

**Architecture:** Keep `RosterEditDraft`, existing Contacts save/tag/avatar logic, and current list/navigation state. Share a small observable `ContactEditorBridge` between the global toolbar and selected detail view so toolbar actions can drive inline editing without moving draft data into the root view. Reuse `NativeInfoCard`, `NativeInfoRow`, existing field components, and `RosterTheme` tokens, changing only their geometry where needed.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Package Manager, existing `RosterShared` model/localization.

---

### Task 1: Connect selected-contact edit state to the Contacts toolbar

**Files:**
- Modify: `Sources/RosterApp/Views/Contacts/ContactsEditorView.swift` (`ContactsEditorView`, `ContactsToolbar`, `ContactRosterEditor` call sites)

- [ ] Add an observable `ContactEditorBridge` owned by `RootView`.
- [ ] Pass the bridge to `ContactsToolbar`, `TagsToolbar`, and `ContactRosterEditor`.
- [ ] Reset edit mode when selected contact or selection mode changes.
- [ ] Add toolbar controls: view mode shows `Edit` only when a profile is selected; edit mode shows `Cancel` and prominent `Done`; selection mode keeps existing bulk controls.
- [ ] Move save/cancel responsibility out of the detail bottom action bar into the binding-driven toolbar while preserving the existing async save and validation behavior.

### Task 2: Replace the detail hero and countdown banner

**Files:**
- Modify: `Sources/RosterApp/Views/Contacts/ContactsEditorView.swift` (`ContactRosterEditor`)

- [ ] Replace the centered 96pt `hero` with a left-aligned 72pt identity header, name/subtitle, quick actions, avatar selection, and existing drag payload.
- [ ] Replace the filled countdown banner with an inline bordered occurrence strip; use a subtle red tint only for today.
- [ ] Add a dashed no-birthday strip and hide the empty birthday group in view mode.
- [ ] Preserve existing occurrence and age calculations and reduce-motion transitions.

### Task 3: Restructure view and edit content into captioned groups

**Files:**
- Modify: `Sources/RosterApp/Views/Contacts/ContactsEditorView.swift` (`readCards`, `editCards`, helper views)

- [ ] Create a small `ContactDetailSection` wrapper for caption + existing group box.
- [ ] View order: birthdays, tags, contact methods, work; keep extended Apple fields as a separate read-only section when enabled.
- [ ] Edit order: name, birthdays, tags, work, contact methods; keep field bindings and existing popovers.
- [ ] Keep row geometry identical between view/edit modes and remove the bottom action bar.

### Task 4: Align native row/card tokens to the approved Inspector geometry

**Files:**
- Modify: `Sources/RosterApp/Views/Contacts/ContactsEditorView.swift` (`NativeInfoCard`, `NativeInfoRow`, `NativeDivider`)

- [ ] Use 84pt trailing-aligned labels, 9pt vertical row padding, 38pt minimum row height, and separators inset after the label column.
- [ ] Reduce group shadow to one subtle layer while preserving light/dark behavior.
- [ ] Keep shared components compatible with batch-edit and extended-field callers.

### Task 5: Verify the focused behavior and build

**Files:**
- Test: existing `Tests/RosterAppTests/RosterAppTests.swift`
- Test: existing `Tests/RosterCoreTests/RosterCoreTests.swift`

- [ ] Run `swift test --filter RosterAppTests` or the smallest relevant existing filter after inspecting test names.
- [ ] Run `swift build`.
- [ ] Run `git diff --check` and inspect only the intended source diff.
- [ ] Report that real macOS interaction, dark mode, Reduce Motion, and app bundle verification remain unrun unless a local app build is explicitly requested.

# macOS E2E Drag And Drop

Roster is a SwiftPM macOS app, so browser E2E tools do not cover native drag
and drop. Use a small fixture mode plus JXA/System Events for the critical
contact assignment workflow.

## Scope

- Test fixture: launch the app with `--roster-e2e contact-drag`.
- Source: `contact-row-e2e-ada`.
- Targets: `contact-tag-drop-e2e-vip` and `contact-group-drop-group:e2e-friends`.
- Assertion: the dropped contact shows the assigned tag/group result in the UI.

## Run

```bash
scripts/e2e/contact-drag-and-drop.sh
```

The script builds the app, launches a fixture instance, performs a real mouse
drag from the contact row to the tag chip, and checks the visible UI state.
Grant Accessibility permission to the terminal running the script if macOS
blocks System Events input.

## Rules

- Keep fixture data deterministic and isolated from real macOS Contacts data.
- Prefer accessibility identifiers over layout or text-only selectors.
- After changing drag/drop behavior, run this E2E script before publishing.

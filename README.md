# Birthday

Birthday is a local-first macOS Contacts birthday manager.

The first version is intentionally small:

- Reads birthdays from macOS Contacts.
- Writes edits back to `CNContact.birthday` and `CNContact.nonGregorianBirthday`.
- Supports Gregorian, Chinese lunar, Hebrew, and Islamic/Hijri birthdays.
- Uses Foundation `Calendar` for date conversion and occurrence calculation.
- Provides calendar, list, contact editor, permission/settings, and voice date conversion views.
- Supports Simplified Chinese, Traditional Chinese, and English interface strings.

## Run

Build a local `.app` bundle:

```bash
scripts/build-app.sh
```

The generated app is:

```text
.build/Birthday.app
```

Build a release version (optimized build, versioned zip in `dist/`):

```bash
scripts/build-app.sh release
```

Outputs `dist/Birthday.app` and `dist/Birthday-<version>.zip`.

Run tests:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift test --scratch-path "$PWD/.build"
```

Build directly:

```bash
env CLANG_MODULE_CACHE_PATH="$PWD/.tmp-swift-cache" swift build --scratch-path "$PWD/.build"
```

## Architecture

```text
BirthdayApp
- SwiftUI views
- App state
- Localization
- Voice input service

BirthdayCore
- ContactsRepository
- Birthday models
- BirthdayOccurrenceResolver
- CalendarFormattingService
- DatePhraseParser
```

Contacts remains the source of truth. User defaults and future account services should store preferences, sharing metadata, or account state only, not a private copy of contact birthdays.

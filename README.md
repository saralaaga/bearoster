# Roster / 名册

Roster is a local-first macOS Contacts manager for organizing people with groups,
tags, birthday data, and local edit history.

The first version is intentionally small:

- Reads birthdays from macOS Contacts.
- Writes edits back to `CNContact.birthday` and `CNContact.nonGregorianRoster`.
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
.build/Roster.app
```

Build a release version (optimized build, versioned zip in `dist/`):

```bash
scripts/build-app.sh release
```

Outputs `dist/Roster.app` and `dist/Roster-<version>.zip`.

Update the local install package after code changes:

```bash
scripts/update-local-package.sh
```

This bumps the build number in `Packaging/VERSION`, rebuilds the release zip, and installs the app to `/Applications/Roster.app`.

The app version is defined once in `Packaging/VERSION`. The build script writes
that version into debug and release app bundles and uses it for the release zip
name.

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
RosterApp
- SwiftUI views
- App state
- Localization
- Voice input service

RosterCore
- ContactsRepository
- Roster models
- RosterOccurrenceResolver
- CalendarFormattingService
- DatePhraseParser
```

Roster keeps a local working copy for pending contact edits, history, and
trash state. macOS Contacts remains the external system of record for data that
the user chooses to write back.

## Source

Public repository: [github.com/saralaaga/bearoster](https://github.com/saralaaga/bearoster)

## License

This project is released under the [MIT License](LICENSE).
Copyright © 2026 Bang Ni Wen Wen (Tianjin) E-Commerce Co., Ltd.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)（中文贡献指南：构建、测试、PR / Issue 约定与隐私注意）。

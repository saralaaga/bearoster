# Copy review — Chinese & English user-facing strings

Read-only audit. No files were modified. Date: 2026-09-05.

Scope: `Sources/RosterShared/RosterLocalization.swift`, `Sources/RosterApp/RosterLocalization.swift`,
and all SwiftUI string literals in `Sources/RosterApp/`, `Sources/RosterShared/`, `Sources/RosterIOSApp/`.

Reference standard used for English: Apple macOS HIG capitalization (title case for buttons, menu
items, and window/pane titles; sentence case for labels, field titles, and body text), plus Apple
Contacts / System Settings terminology.

---

## P0 — Blocking correctness issues

### 1. `ContactSyncHistoryView.swift` is 100% hardcoded Chinese

`Sources/RosterApp/Views/Contacts/ContactSyncHistoryView.swift` — the entire "Sync & History" pane
renders Simplified Chinese regardless of `model.language`. An English or Traditional Chinese user
sees Simplified Chinese here. This is the single largest copy defect found.

Sidebar reaches this pane via `SidebarView.swift:71` using the localized `L10n.syncHistory`
("Sync & History"), and `RosterRootView.swift:205` sets the toolbar title from the same key — so
the entry point is localized but the pane body is not. The pane header also *contradicts* the
sidebar label: sidebar says 同步与历史 / "Sync & History", header says 缓存与历史.

Every string below needs a new `L10n` key. Proposed keys and all three locales:

| Line | Current (hardcoded) | Proposed key | zhHans | zhHant | en |
|---|---|---|---|---|---|
| 14, 15 | 写入模式 | `writePolicy` | 写入模式 | 寫入模式 | Write mode |
| 19 | 仅本地 | `writePolicyLocalOnly` | 仅本地 | 僅本機 | Local only |
| 20 | 确认后写入 | `writePolicyConfirm` | 确认后写入 | 確認後寫入 | Ask before writing |
| 21 | 自动写入 | `writePolicyAutomatic` | 自动写入 | 自動寫入 | Write automatically |
| 28 | 队列 | `queue` | 队列 | 佇列 | Queue |
| 30, 54, 291 | 待写入 | `statusPending` | 待写入 | 待寫入 | Pending |
| 31, 46, 294 | 冲突 | `statusConflict` | 冲突 | 衝突 | Conflicts |
| 32, 50, 293 | 失败 | `statusFailed` | 失败 | 失敗 | Failed |
| 37 | 写入待处理 | `writePending` | 写入待处理 | 寫入待處理 | Write Pending Changes |
| 61 | 历史记录 | `history` | 历史记录 | 歷史記錄 | History |
| 74 | 缓存与历史 | reuse `syncHistory` | 同步与历史 | 同步與歷史 | Sync & History |
| 76 | 软件内修改先保存在本地缓存，本页负责确认写回、冲突处理、失败重试和撤销回退。 | `syncHistoryBody` | 应用内的修改先保存在本地，在这里确认写回通讯录、处理冲突、重试失败的操作或撤销改动。 | 應用內的修改先儲存在本機，在這裡確認寫回通訊錄、處理衝突、重試失敗的操作或復原改動。 | Changes are saved locally first. Review them here to write them back to Contacts, resolve conflicts, retry failures, or undo. |
| 114 | 没有记录 | `noEntries` | 没有记录 | 沒有記錄 | No entries |
| 129 | 回收站 | `trash` | 回收站 | 垃圾桶 | Recently Deleted |
| 140 | 本地回收站 | `trashLocal` | 本地回收站 | 本機垃圾桶 | In local trash |
| 148 | 恢复 | `restore` | 恢复 | 復原 | Restore |
| 262 | 使用 macOS 版本 | `keepMacOSVersion` | 使用 macOS 版本 | 使用 macOS 版本 | Keep macOS Version |
| 267 | 用本地覆盖 | `keepLocalVersion` | 用本地版本覆盖 | 用本機版本覆蓋 | Keep My Version |
| 292 | 已写入 | `statusApplied` | 已写入 | 已寫入 | Written |
| 295 | 已放弃 | `statusReverted` | 已放弃 | 已放棄 | Discarded |

Rationale for the non-literal English choices:

- **"Ask before writing"** rather than "Write after confirmation": the confirmation-prompt pattern
  is phrased as *Ask* throughout Apple's UI ("Ask Before Deleting", "Ask to Join Networks"). A
  literal render reads like machine translation.
- **"Recently Deleted"** rather than "Trash"/"Recycle Bin": Apple Contacts, Photos, and Notes all
  label their soft-delete area *Recently Deleted*. "Recycle Bin" is a Windows term and "Trash"
  collides with the Finder Trash, which this is not.
- **"Keep macOS Version" / "Keep My Version"**: conflict resolvers name the *outcome* (what you
  keep), not the mechanism (overwrite). 用本地覆盖 is also asymmetric with 使用 macOS 版本 in
  Chinese — one uses 使用, the other 覆盖. Making both 使用/用…覆盖 → parallel "使用 macOS 版本" /
  "用本地版本覆盖" reads more evenly.
- **"Discarded"** rather than "Reverted": user-facing copy for an abandoned pending change; the
  enum case is `.reverted` but users think of it as discarded. Reverted implies a rollback happened.

Also at line 250: `Text("\(change.field): \(change.previousValue) -> \(change.nextValue)")` uses an
ASCII `->`. Use the arrow character `→` (already used in `CalendarViews.swift:358`) for consistency
and typographic correctness.

### 2. `RosterIOSApp/` is entirely hardcoded Simplified Chinese

All six iOS view files ship Simplified Chinese literals with no localization path at all, while
`RosterShared/RosterLocalization.swift` is already `package`-visible to that target. Affected:
`MobileRootView.swift:16,20,24,28`; `MobileContactsView.swift:25,35,36,41,49,66,71`;
`MobileTagsView.swift:11,12,13,16,18,39`; `MobileCalendarView.swift:11,32,37`;
`MobileMoreView.swift:12-29`; `MobileContactDetailView.swift:29,31,36,38,52,55,63,65,68,71,82`.

Most map to existing keys (`.contacts`, `.tags`, `.calendar`, `.birthday`, `.noTags`, `.email`,
`.department`, `.jobTitle`, `.edit`, `.untaggedContacts`, `.all`, `.displayAge`, `.appLanguage`).
Ones needing new keys: 更多 → `more` ("More"), 智能分组 → `smartGroups` ("Smart Groups"),
我的标签 → `myTags` ("My Tags"), 同步 → `sync` ("Sync"), 待写回 → reuse `statusPending`,
没有日期 → `noDates` ("No Dates"), 联系人不可用 → `contactsUnavailable` ("Contacts Unavailable"),
手机 → `mobilePhone` ("mobile"), 更多资料 → `moreFields` ("More Fields"),
新建联系人 → `newContact` ("New Contact"), 搜索姓名、公司、标签 → `searchContactsPrompt`
("Search names, companies, tags").

Note `MobileMoreView.swift:21-24` offers a language Picker with only 跟随系统 / 简体中文 / 繁體中文
— `AppLanguage.en` is missing, so an iOS user cannot select English at all. That's a functional gap,
not just copy; flagging for the owner.

### 3. `Sources/RosterApp/RosterLocalization.swift` is dead duplicate code

`Sources/RosterApp/RosterLocalization.swift` and `Sources/RosterShared/RosterLocalization.swift`
are byte-identical apart from `package` access modifiers. `RosterApp` depends on `RosterShared`
(`Package.swift:34`), so the shared one wins at every call site and the `RosterApp` copy is
unreachable. Any copy fix applied to only one file silently does nothing.

Recommendation: delete `Sources/RosterApp/RosterLocalization.swift` before any copy edit lands, so
there is one source of truth. **This is a code change beyond copy scope — needs owner sign-off.**
Until then, every suggestion in this document must be applied to *both* files.

---

## P1 — AI-sounding / unnatural English

### 4. `aboutBody` — headless fragment, machine-assembled rhythm

`RosterLocalization.swift:68` (both files)

- Current en: `Built for bulk contact cleanup. It keeps writes conservative by default, lets you choose what gets overwritten, and previews changes before they’re applied.`
- Revised en: `Bearoster is for cleaning up a lot of contacts at once. It only fills in blanks unless you say otherwise, and shows you every change before it’s saved.`

Rationale: the current text is the clearest AI tell in the app. Three problems: it opens with a
headless participle ("Built for…") with no subject, which is marketing-deck voice rather than an
About pane; "keeps writes conservative" is developer jargon a user cannot act on ("conservative"
describes the code's disposition, not what happens to their data); and the three-clause
"keeps… , lets… , and previews…" tricolon is the characteristic LLM cadence. The revision names the
app, states the write behavior in terms the user can verify against the Write policy control they
will actually see, and drops to two clauses.

- Current zhHans: `这套界面适合批量整理联系人。默认谨慎写入，可选择是否覆盖已有内容，并在应用前预览改动。`
- Revised zhHans: `蓝熊名册适合一次整理大量联系人。默认只填空白项，你也可以选择覆盖已有内容，改动保存前都能先预览。`
- Revised zhHant: `藍熊名冊適合一次整理大量聯絡人。預設只填空白項，你也可以選擇覆蓋既有內容，改動儲存前都能先預覽。`

Rationale (zh): 这套界面 is odd as an About-pane subject — the user opened *the app*, not "this
interface"; naming the product is more natural. 谨慎写入 is a translation of "conservative writes"
and means little to a Chinese user; 只填空白项 states the actual behavior and matches the
仅填写空项 label in the batch editor. 并在应用前预览改动 uses 应用 as a verb ("apply"), which
collides with 应用 = "app" used elsewhere in this same file (`contactGroupAccessBody` says
按应用授权); 保存前 avoids the collision.

### 5. `extendedContactFieldsBody` — wrong product name, list-dump rhythm

`RosterLocalization.swift:168`

- Current en: `When enabled, Roster also reads extra fields such as URLs, social profiles, relationships, dates, and avatars. Basic contact fields are still available.`
- Revised en: `Also reads websites, social accounts, related people, dates, and photos from Contacts. Everyday fields keep working either way.`

Rationale: **"Roster" is the old product name** — the app is Bearoster now (renamed in commits
`564acb1`, `0c683c4`). This string is the only place the stale name is still visible to users; it
must change regardless of tone. Beyond that: "When enabled, X also…" is boilerplate for a toggle
whose state the user can already see, so it's cut. "URLs" is developer-facing (Contacts labels the
field *Website*); "relationships" is Contacts' *Related People*; "avatars" is developer-speak for
what Contacts calls a *photo*. "Basic contact fields are still available" reads as a reassurance
generated to fill the paragraph — "keep working either way" says the same thing in the user's terms.

- Revised zhHans: `会额外读取通讯录里的网址、社交账号、关联人、日期和照片。常用字段不受影响。`
- Revised zhHant: `會額外讀取通訊錄裡的網址、社群帳號、關聯人、日期和照片。常用欄位不受影響。`

Rationale (zh): 开启后 is redundant next to the switch. 头像 → 照片 matches Apple 通讯录's own
照片 label. 关系 → 关联人 matches Contacts' 关联人 field name. 仍然可用 ("still available") is a
literal render; 不受影响 is what a Chinese user expects here.

### 6. `invalidDatePhrase` — passive voice, "convertible" is not user language

`RosterLocalization.swift:180`

- Current en: `No convertible birthday date was recognized.`
- Revised en: `Couldn’t find a date to convert. Try “lunar June 8.”`
- Current zhHans: `没有识别出可换算的生日日期。`
- Revised zhHans: `没听出要换算的日期，可以试试「农历六月初八」。`
- Revised zhHant: `沒聽出要換算的日期，可以試試「農曆六月初八」。`

Rationale: "No convertible X was recognized" is triple-flagged — passive voice, a coined adjective
("convertible" describes the parser's capability, not anything the user did), and no recovery path.
Apple's error-message guidance is to say what happened and what to try next. The revision does both
and reuses the example already in `voicePlaceholder`, so the suggestion matches what the user was
shown before speaking. zh: 识别出 is OCR/ASR jargon; 没听出 fits a dictation feature.

### 7. `permissionBody` — "Nothing is uploaded" is vaguer than the Chinese

`RosterLocalization.swift:155`

- Current en: `Used to read and update birthdays. Changes are saved directly in macOS Contacts. Nothing is uploaded, and no account is required.`
- Revised en: `Bearoster reads and updates birthdays in your Contacts. Nothing leaves your Mac, and there’s no account to sign in to.`

Rationale: "Used to read…" is a headless fragment (same tell as `aboutBody`), which is especially
weak in a permission prompt — the one screen where the user wants to know *who* is asking. The
Chinese says 不会上传联系人 (your contacts are not uploaded); "Nothing is uploaded" is weaker and
vaguer than its own source. "Nothing leaves your Mac" is the concrete claim, and it's true given
the app writes only to local Contacts. "no account is required" → "there's no account to sign in
to" removes the passive and reads like a person wrote it.

- Revised zhHans: `蓝熊名册用来读取和更新通讯录里的生日。生日直接保存在 macOS 通讯录，不会离开你的 Mac，也不需要注册或登录。`
- Revised zhHant: `藍熊名冊用來讀取和更新通訊錄裡的生日。生日直接儲存在 macOS 通訊錄，不會離開你的 Mac，也不需要註冊或登入。`

### 8. `previewLine` — "Fill name for 3 contacts" is not English

`ContactsEditorView.swift:982-991`

```swift
let verb = fillPolicy == .onlyEmpty ? "Fill" : "Overwrite"
return "\(verb) \(title.lowercased()) for \(contactCountText(count))"
```

- Current en (rendered): `Fill given name for 3 contacts` / `Overwrite job title for 1 contact`
- Revised en (rendered): `3 contacts: fill Given name` / `1 contact: overwrite Job title`

Rationale: this is programmatic English assembly and it reads that way. "Fill given name for 3
contacts" is ungrammatical — *fill in* takes a particle, and the bare noun needs an article. It also
`.lowercased()`s the field label, which breaks proper nouns and Apple's own field names, and
lowercasing is locale-unsafe (`.lowercased()` without a locale mangles Turkish dotted-I). Leading
with the count also matches the Chinese structure and makes a scanned list of preview lines align.

Suggested shape:

```swift
case .english:
    let verb = fillPolicy == .onlyEmpty ? "fill" : "overwrite"
    return "\(contactCountText(count)): \(verb) \(title)"
```

The zh forms at 987/989 are fine in meaning but `影响 \(count) 人` uses the bare measure word 人
while `contactCountText` in the same file uses `位联系人`. Align on one — suggest
`\(title)：\(...)，\(count) 位联系人`.

### 9. `previewRenameSummary` — "affects N contacts" is ominous without a verb

`ContactsEditorView.swift:885, 889, 893`

- Current en: `Replacing “Tom” affects 4 contacts` / `Adding prefix “VIP - ” affects 12 contacts`
- Revised en: `Renames 4 contacts` (replace) / `Adds “VIP - ” to 12 names` (prefix) / `Adds “ (Client)” to 12 names` (suffix)

Rationale: "X affects N contacts" is the generic phrasing an LLM reaches for when it doesn't know
what the operation does — it tells the user something will happen to 4 contacts without saying
what. The user already sees the find/replace values in the fields directly above, so restating them
in the summary is redundant; the summary's job is the *outcome*. Same for zh: 会影响 N 人 →
`重命名 4 位联系人` / `给 12 个姓名加上「VIP - 」`.

### 10. `noContactGroups` / `readOnlyExtendedFields` — reporting from the app's side

`RosterLocalization.swift:203`

- Current en: `No contact groups found in Apple Contacts.`
- Revised en: `No groups in Apple Contacts yet.`

Rationale: "No X found in Y" is a search-result report; here it's an empty state for something the
user can create. "yet" signals the state is expected and changeable. zh: 未从 Apple 通讯录读到分组。
→ `Apple 通讯录里还没有分组。` — 读到 exposes the read operation; the user cares about the absence,
not the read.

`RosterLocalization.swift:148`

- Current en: `Other extended fields are currently read from Apple Contacts.`
- Revised en: `These come from Apple Contacts and can’t be edited here.`

Rationale: the current sentence states the app's data flow but not the consequence — the user reads
it and still doesn't know why the fields are greyed out. "currently" is a hedge with no expiry. The
key is literally named `readOnlyExtendedFields`, so read-only is the intent; say so.
zh: 其它扩展字段当前只从 Apple 通讯录读取。 → `这些字段来自 Apple 通讯录，不能在这里编辑。`

### 11. `notWiredYet` — internal engineering status leaked to users

`RosterAppModel.swift:1902-1904`

- Current en: `Creating full macOS contacts is not wired yet.`
- Revised en: `Bearoster can’t create new contacts in macOS Contacts yet. Add them in Contacts and they’ll show up here.`

Rationale: "not wired yet" is engineering-internal — it describes the state of the codebase, not the
product, and a user has no idea what "full macOS contacts" means as opposed to partial ones. Give
the limitation plus the workaround. zh: 创建完整 macOS 联系人的写回还未接入。 →
`还不能在 macOS 通讯录里新建联系人，可以先在通讯录里添加，这里会同步显示。` (写回/接入 are
both internal terms.)

### 12. Progress messages — gerund pile, and the visible one is unlocalized

`RosterAppModel.swift` passes English-only literals to `scheduleDerivedDataRebuild(message:)` at
lines 135, 163, 166, 169, 177, 182, 200, 293, 456, 799, 856, 887, 944, 974, 1052, 1076, 1105, 1121,
1136, 1238, 1293, 1344, 1411, 1462. Those land in `startCalculationProgress` →
`calculationProgress.message` → `CalculationProgressView` at `RosterComponents.swift:181`, i.e.
**they are visible to the user in every language**. `RosterDerivedDataWorker.swift` localizes its
own progress strings properly via `progressText(zhHans:zhHant:en:)`, so the two halves of the same
progress bar disagree: a Chinese user sees "Filtering roster data" then 筛选生日记录.

Two issues to fix together:

1. Route the `RosterAppModel` messages through `L10n` (or through the same `progressText` helper),
   so the pane is single-language.
2. The strings themselves say "roster data", an internal noun the user never sees in the UI
   (`L10n.list` renders as "Rosters", `L10n.birthdayRecords` as "Roster records", but the data
   itself is birthdays). Suggest collapsing 24 near-duplicate messages to four keys the worker
   already has vocabulary for: `Preparing birthdays` / `Filtering birthdays` / `Sorting birthdays` /
   `Updating birthdays` (zhHans: 准备生日 / 筛选生日 / 排序生日 / 更新生日).

`RosterDerivedDataWorker.swift:102,112` says `Calculating visible month` / 计算当前月份 — "visible
month" is a variable name (`visibleMonth`). Suggest `Calculating this month` / 计算本月.

### 13. `VoiceInputService` errors are English-only and passive

`VoiceInputService.swift:16` — `"Speech recognition and microphone access are required."`
`VoiceInputService.swift:25` — `"Speech recognition isn’t available for this language."`

These reach the user through `NSLocalizedDescriptionKey` and the alert at `RosterRootView.swift:73`,
but they never pass through `L10n`, so Chinese users get English. Line 16 is also passive with no
action; suggest `Bearoster needs access to the microphone and speech recognition. You can turn both
on in System Settings > Privacy & Security.` / `需要麦克风和语音识别权限，可以在系统设置 >
隐私与安全性中开启。`

---

## P2 — Capitalization and terminology consistency (English)

The English strings mix title case and sentence case for the same *kind* of control, which is the
most visible non-native signal after tone. Per HIG: buttons and menu items take title case; labels,
field titles, and picker option text take sentence case.

**Buttons/menu items that should be title case but are sentence case:**

| Key | Current | Revised | Site |
|---|---|---|---|
| `addRoster` | Add birthday | Add Birthday | `ContactsEditorView.swift:1280` Label in button |
| `deleteRoster` | Delete birthday | Delete Birthday | `ContactsEditorView.swift:1727` `.help` |
| `newTag` | New tag | New Tag | `TagsView.swift:111` button Label |
| `removeTag` | Remove tag | Remove Tag | `ContactsEditorView.swift:2081` `.help` |
| `deleteTagTitle` | Delete tag | Delete Tag | `SidebarView.swift:163` alert title — and it duplicates `deleteTag` ("Delete Tag") exactly; merge the two keys |
| `newTagPathPlaceholder` | New tag, use / for child tags | (keep sentence case — it's a field placeholder) | — |

**Labels/options that should be sentence case but are title case:**

| Key | Current | Revised | Site |
|---|---|---|---|
| `birthdayStatus` | Birthday Status | Birthday status | `ContactsEditorView.swift:375` row label |
| `hasBirthday` | Has Birthday | Has birthday | picker option, `:394` |
| `missingBirthday` | Missing Birthday | No birthday | picker option, `:395` — also aligns with the `missingPhone`/`missingEmail` pattern already revised to "No phone number"/"No email address" |
| `upcomingBirthday` | Upcoming Birthday | Birthday soon | picker option, `:396` |
| `contactInfo` | Contact Info | Contact info | section label (currently orphaned) |
| `appleGroups` | Apple Groups | Apple groups | section label (currently orphaned) |

**Terminology:**

- `list` renders as **"Rosters"** (`SidebarView.swift:87`, `RosterRootView.swift:253`) while its
  zhHans is 生日列表 ("birthday list"). "Rosters" as a plural noun for a list of birthdays is not
  something an English user will parse — and it's now doubly confusing since the app is Bearoster,
  so "Rosters" reads like a section of app-branded objects. Suggest **"Birthdays"** (matching the
  Chinese) or **"All Birthdays"**. Same for `birthdayRecords` ("Roster records" → "Birthdays").
- `nearest` renders "Next birthday" as a sort option; the pane it sorts is also about birthdays, so
  in `RosterRootView.swift:312` the option can be just **"Next"** — or keep it and shorten
  `RosterDerivedDataService.swift:205` which duplicates the same "Next birthday" string. Right now
  the identical English lives in two places and can drift.
- `listening` is `"Listening..."` with three ASCII periods, while the zh forms use the ellipsis
  character (`正在听写…`). Use `Listening…` (U+2026) — Apple uses the character, and ASCII dots are
  a common machine-generated tell.
- `videoCall` renders as "Video" (`ContactsEditorView.swift:1561`) next to Message and Phone.
  Apple's Contacts action row labels this **FaceTime**. If the action opens FaceTime, say FaceTime.
- `permissionDenied` uses `>` as the settings-path separator: `System Settings > Privacy & Security
  > Contacts`. macOS uses the right-pointing angle `›` or an em-dash chain in prose. Low priority
  but it's the kind of detail native reviewers notice.
- `syncHistory` is "Sync & History" — a two-noun ampersand title is unusual for a macOS pane and
  the pane is really a queue of pending writes. Suggest **"Sync"** or **"Pending Changes"**. If it
  stays, the Chinese 同步与历史 and the pane header 缓存与历史 must be reconciled (see P0 #1).

---

## P3 — Chinese-side issues

### 14. Simplified/Traditional pairs that were not actually converted

`RosterAppModel.swift:1927-1928` — 将 \(name) 移入回收站 / 將 \(name) 移入回收站. The zhHant
form keeps 回收站; Traditional Chinese (TW/HK) uses 垃圾桶 for this. Same at
`ContactSyncHistoryView.swift:129,140` (hardcoded, see P0 #1) and `RosterAppModel.swift:1911`
(已從回收站恢復到本機).

`RosterLocalization.swift:108` — `localOnly` zhHans 本地保存 / zhHant 本機保存. Fine. But
`RosterAppModel.swift:1911` zhHant says 恢復到本機 while `ContactSyncHistoryView.swift` (hardcoded)
would say 本地. Once #1 is localized, standardize on 本地 (zhHans) / 本機 (zhHant) everywhere.

### 15. Measure-word and counting inconsistency

Three different Chinese count patterns for the same thing coexist:

- `位联系人` — `TagsView.swift:201`, `ContactsEditorView.swift:996,2319`, `RosterAppModel.swift:1851`
- `人` (bare) — `ContactsEditorView.swift:885,889,893,987`
- `个/位` mixed — `PermissionsSettingsView.swift:350` (已选 N 个分组，包含 N 位联系人)

Standardize on `N 位联系人` / `N 位聯絡人` for people and `N 个分组` / `N 個分組` for groups.

### 16. `voicePlaceholder` en/zh mismatch

`RosterLocalization.swift:175`

- zhHans: 例如：农历六月初八是公历几号 (asks a full question)
- en: `Example: What date is lunar June 8?`

"lunar June 8" is not how an English speaker names a Chinese lunar date — the lunar calendar's sixth
month isn't June. Suggest `Example: 6th month, 8th day on the lunar calendar` or, if the parser
accepts it, `Example: lunar 6/8`. Worth checking against `DatePhraseParser.swift:51` which matches
on `"lunar"`/`"chinese"` — confirm the suggested phrasing actually parses before shipping it as a
placeholder, otherwise the example fails when a user types it verbatim. **Needs owner verification.**

### 17. `daysSuffix` renders "3 days" as two stacked elements

`ContactsEditorView.swift:1178-1182, 1485-1491` composes `Text("\(days)")` + `Text(daysSuffix)`
where `daysSuffix` is `"days"` / `"天后"` / `"天後"`. In English this renders **"3 days"** with no
preposition, while the equivalent `daysLeftText` in `RosterTheme.swift:195` renders **"in 3 days"**.
Two different countdown phrasings for the same concept. Also `"days"` is unconditionally plural, so
`days == 1` renders "1 days".

Suggest reusing `daysLeftText` here, or if the stacked big-number layout must stay, make the suffix
`days == 1 ? "day" : "days"` and drop the "in" from `daysLeftText` so both read as bare durations.

### 18. `Turns \(age)` duplicated in three files

`ContactsEditorView.swift:1501,1688,1800` and `ContactListProjectionService.swift:506` all define
identical `ageValueText`/`ageText`. Four copies of the same string will drift. Consolidate into one
`L10n` key or one shared helper. ("Turns 34" itself is good, natural English — no copy change.)

---

## Orphaned keys (no call sites — copy fixes here have no user impact)

Verified by grepping `.<key>` across `Sources/` and `Tests/` excluding the two localization files:
`about`, `aboutBody`, `birthdayRecords`, `appleGroups`, `contactInfo`, `notes`, `nextRoster`,
`dataSource`, `extendedContactFieldsBody`, `supportedCalendars`, `voicePlaceholder`, `convertDate`,
`listening`, `startListening`, `stopListening`, `contactsDeleted`, `deleteContactsFailed`.

Notable: `aboutBody` and `extendedContactFieldsBody` are the two longest and most AI-sounding
strings in the file (#4, #5) and **neither is currently rendered anywhere**. The About pane and the
extended-fields explainer appear to have been dropped from the UI. Two readings, and the owner
should pick: either these are dead code to delete, or the panes regressed and the strings should be
wired back up. I'd revise the copy either way — cheap, and if the panes return the text is ready.

The voice-input cluster (`voicePlaceholder`, `convertDate`, `listening`, `startListening`,
`stopListening`) is orphaned in the views even though `RosterAppModel.swift:1555,1575` still drives
`voiceResult` and `VoiceInputService` is still instantiated at `:261`. So the voice feature has
model-layer plumbing and no UI. Same question for the owner.

`contactsDeleted` and `deleteContactsFailed` being orphaned is more concerning: `deleteContacts`
and `deleteContactsMessage` *are* used, so the delete flow exists but appears to report neither
success nor failure to the user. Worth a separate look — that's behavior, not copy.

---

## Summary of files needing edits

| File | Items |
|---|---|
| `Sources/RosterShared/RosterLocalization.swift` | #4-7, #10, #16, P2 all, plus ~20 new keys for #1 |
| `Sources/RosterApp/RosterLocalization.swift` | same — or delete the file (#3) |
| `Sources/RosterApp/Views/Contacts/ContactSyncHistoryView.swift` | #1 (full localization), arrow char |
| `Sources/RosterApp/Views/Contacts/ContactsEditorView.swift` | #8, #9, #17, #18, P3 #15 |
| `Sources/RosterShared/RosterAppModel.swift` | #11, #12, P3 #14 |
| `Sources/RosterShared/Services/RosterDerivedDataWorker.swift` | #12 (visible month) |
| `Sources/RosterShared/VoiceInputService.swift` | #13 |
| `Sources/RosterShared/Services/ContactListProjectionService.swift` | #18 |
| `Sources/RosterShared/Services/RosterDerivedDataService.swift` | P2 (duplicate "Next birthday") |
| `Sources/RosterApp/Views/Settings/PermissionsSettingsView.swift` | P3 #15 |
| `Sources/RosterApp/Views/Tags/TagsView.swift` | P3 #15 |
| `Sources/RosterIOSApp/*.swift` (6 files) | #2 |

Suggested order: #3 (de-duplicate) → #1 and #2 (unlocalized panes) → #4-13 (tone) → P2/P3 (polish).
#3 first because every other localization-file edit is otherwise done twice.

import AppKit
import BirthdayCore
import Foundation
import Observation

enum SidebarSelection: String, CaseIterable, Identifiable {
    case calendar
    case list
    case contacts
    case permissions

    var id: String { rawValue }
}

enum BirthdaySort: String, CaseIterable, Identifiable, Sendable {
    case next
    case name
    case age
    case calendar

    var id: String { rawValue }
}

struct BirthdayRecordGroup: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let occurrences: [BirthdayOccurrence]
}

@MainActor
@Observable
final class BirthdayAppModel {
    var selection: SidebarSelection = .permissions
    var permissionState: ContactsPermissionState = .notDetermined
    var selectedContactID: String?
    var searchText = "" {
        didSet {
            scheduleDerivedDataRebuild(message: "Searching birthdays", debounceNanoseconds: 250_000_000)
        }
    }
    var contactSearchText = "" {
        didSet {
            rebuildContactProjection()
        }
    }
    var selectedDate = Date() {
        didSet { selectedDateOccurrences = cachedRecords(on: selectedDate) }
    }
    var visibleMonth = Date() {
        didSet { scheduleDerivedDataRebuild(message: "Calculating month") }
    }
    var filter: BirthdayCalendarKind? {
        didSet { scheduleDerivedDataRebuild(message: "Filtering birthdays") }
    }
    var sort: BirthdaySort = .next {
        didSet { scheduleDerivedDataRebuild(message: "Sorting birthdays") }
    }
    var isLoading = false
    var errorMessage: String?
    var toastMessage: String?
    var language: AppLanguage = .system {
        didSet {
            rebuildContactProjection()
            scheduleDerivedDataRebuild(message: "Updating language")
        }
    }
    var showAge = true
    var upcomingRange = 30 {
        didSet { scheduleDerivedDataRebuild(message: "Calculating upcoming birthdays") }
    }
    var selectedContactCollectionID = ContactCollectionIdentifier.all {
        didSet {
            rebuildContactProjection()
        }
    }
    private(set) var contactAccessScope: ContactAccessScope = BirthdayAppModel.loadContactAccessScope()
    var contactFieldAccessLevel: ContactFieldAccessLevel = BirthdayAppModel.loadContactFieldAccessLevel() {
        didSet {
            guard contactFieldAccessLevel != oldValue else { return }
            Self.saveContactFieldAccessLevel(contactFieldAccessLevel)
            Task { await refreshContacts() }
        }
    }
    var voiceText = ""
    var voiceResult: String?
    var isListening = false
    var isContactSelectionMode = false
    var selectedContactIDsForDeletion: Set<String> = []
    var isDeletingContacts = false

    private(set) var allRecords: [BirthdayRecord] = []
    private(set) var filteredRecords: [BirthdayRecord] = []
    private(set) var filteredRecordOccurrences: [BirthdayOccurrence] = []
    private(set) var filteredRecordGroups: [BirthdayRecordGroup] = []
    private(set) var profiles: [ContactBirthdayProfile] = []
    private(set) var filteredProfiles: [ContactBirthdayProfile] = []
    private(set) var contactGrouping: ContactGroupingSnapshot = .empty
    private(set) var contactCollectionSections: [ContactCollectionSectionModel] = []
    private(set) var contactListSections: [ContactListSectionModel] = []
    private(set) var visibleContactCount = 0
    private(set) var extendedProfilesByID: [String: ContactExtendedProfile] = [:]
    private(set) var cachedUpcomingOccurrences: [BirthdayOccurrence] = []
    private(set) var selectedDateOccurrences: [BirthdayOccurrence] = []
    private(set) var visibleMonthDates: [Date] = []
    private(set) var visibleMonthTitle = ""
    private(set) var weekdaySymbols: [String] = []
    private(set) var calculationProgress: BirthdayCalculationProgress = .inactive

    let formatter = CalendarFormattingService()
    let resolver = BirthdayOccurrenceResolver()
    let parser = DatePhraseParser()

    private let contactSyncService = ContactSyncService()
    private let localBirthdayStore = LocalBirthdayStore()
    private let derivedDataWorker = BirthdayDerivedDataWorker()
    private let contactListProjection = ContactListProjectionService()
    private let voiceInput = VoiceInputService()
    private var saveTask: Task<Void, Never>?
    private var derivedDataTask: Task<Void, Never>?
    private var contactsRefreshTask: Task<Void, Never>?
    private var contactsChangeObserver: NSObjectProtocol?
    private var dataGeneration = 0
    private var derivedRequestID = 0
    private var profileByID: [String: ContactBirthdayProfile] = [:]
    private var localDateSpecsByPersonID: [String: [BirthdayDateSpec]] = [:]
    private var birthdayRecordSignature = 0
    private var calculationStartedAt: Date?
    private var visibleOccurrencesByDay: [Date: [BirthdayOccurrence]] = [:]
    private var visibleFilteredOccurrencesByDay: [Date: [BirthdayOccurrence]] = [:]

    var l10n: L10n { L10n(language: language) }
    var extendedContactFieldsEnabled: Bool {
        get { contactFieldAccessLevel == .extended }
        set { contactFieldAccessLevel = newValue ? .extended : .birthdayOnly }
    }

    init() {
        observeContactsChanges()
        scheduleDerivedDataRebuild(message: "Preparing birthdays")
        Task { await loadLocalBirthdaySpecs() }
        Task { await loadCachedContactSnapshot() }
    }

    var selectedProfile: ContactBirthdayProfile? {
        guard !isContactSelectionMode else { return nil }
        guard let selectedContactID else { return filteredProfiles.first }
        return profileByID[selectedContactID]
    }

    var selectedContactDeletionCount: Int {
        selectedContactIDsForDeletion.count
    }

    private func scheduleDerivedDataRebuild(message: String, debounceNanoseconds: UInt64 = 0) {
        derivedRequestID += 1
        let requestID = derivedRequestID
        let request = BirthdayDerivedDataRequest(
            generation: dataGeneration,
            profiles: profiles,
            searchText: searchText,
            selectedDate: selectedDate,
            visibleMonth: visibleMonth,
            filter: filter,
            sort: sort,
            language: language,
            upcomingRange: upcomingRange
        )
        let worker = derivedDataWorker

        startCalculationProgress(message: message)
        derivedDataTask?.cancel()
        derivedDataTask = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
                guard !Task.isCancelled else { return }
            }

            let snapshot = await worker.snapshot(for: request) { [weak self] progress in
                Task { @MainActor in
                    guard let self, self.derivedRequestID == requestID else { return }
                    self.calculationProgress = progress
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.derivedRequestID == requestID else { return }
                self.applyDerivedDataSnapshot(snapshot)
                self.finishCalculationProgress(requestID: requestID)
            }
        }
    }

    private func applyDerivedDataSnapshot(_ snapshot: BirthdayDerivedDataSnapshot) {
        allRecords = snapshot.allRecords
        filteredRecords = snapshot.filteredRecords
        filteredRecordOccurrences = snapshot.filteredRecordOccurrences
        filteredRecordGroups = snapshot.filteredRecordGroups
        rebuildContactProjection()
        cachedUpcomingOccurrences = snapshot.cachedUpcomingOccurrences
        selectedDateOccurrences = snapshot.selectedDateOccurrences
        visibleMonthDates = snapshot.visibleMonthDates
        visibleMonthTitle = snapshot.visibleMonthTitle
        weekdaySymbols = snapshot.weekdaySymbols
        visibleOccurrencesByDay = snapshot.visibleOccurrencesByDay
        visibleFilteredOccurrencesByDay = snapshot.visibleFilteredOccurrencesByDay
    }

    private func finishCalculationProgress(requestID: Int) {
        let minimumVisibleSeconds: TimeInterval = 0.45
        let elapsed = calculationStartedAt.map { Date().timeIntervalSince($0) } ?? minimumVisibleSeconds
        let remaining = max(0, minimumVisibleSeconds - elapsed)

        guard remaining > 0 else {
            calculationProgress = .inactive
            return
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            await MainActor.run {
                guard self.derivedRequestID == requestID else { return }
                self.calculationProgress = .inactive
            }
        }
    }

    private func startCalculationProgress(message: String) {
        calculationProgress = BirthdayCalculationProgress(
            isActive: true,
            message: message,
            completed: 0,
            total: 1
        )
        calculationStartedAt = Date()
    }

    private func applyContactSnapshot(_ snapshot: ContactDataSnapshot) {
        let availableGroupIDs = Set(snapshot.grouping.groups.map(\.id))
        let prunedAccessScope = contactAccessScope.pruned(availableGroupIDs: availableGroupIDs)
        if prunedAccessScope != contactAccessScope {
            contactAccessScope = prunedAccessScope
            Self.saveContactAccessScope(prunedAccessScope)
        }

        let mergedProfiles = profilesByApplyingLocalSpecs(to: snapshot.profiles)
        profiles = mergedProfiles
        profileByID = Dictionary(uniqueKeysWithValues: mergedProfiles.map { ($0.id, $0) })
        contactGrouping = snapshot.grouping
        extendedProfilesByID = snapshot.extendedProfilesByID
        if !isContactCollectionSelectable(selectedContactCollectionID) {
            selectedContactCollectionID = ContactCollectionIdentifier.all
        }
        rebuildContactProjection()

        if selectedContactID == nil {
            selectedContactID = filteredProfiles.first?.id ?? snapshot.profiles.first?.id
        } else if let currentSelectedContactID = selectedContactID, profileByID[currentSelectedContactID] == nil {
            selectedContactID = filteredProfiles.first?.id ?? snapshot.profiles.first?.id
        }

        let nextSignature = Self.birthdaySignature(for: mergedProfiles)
        guard nextSignature != birthdayRecordSignature else { return }
        birthdayRecordSignature = nextSignature
        dataGeneration += 1
        scheduleDerivedDataRebuild(message: "Calculating birthdays")
    }

    private func profilesByApplyingLocalSpecs(to profiles: [ContactBirthdayProfile]) -> [ContactBirthdayProfile] {
        profiles.map { profile in
            var merged = profile
            let localSpecs = localDateSpecsByPersonID[profile.id] ?? []
            let localSpecIDs = Set(localSpecs.map(\.id))
            let appleRecords = profile.records.filter { !localSpecIDs.contains($0.id) }
            let localRecords = localSpecs.map { BirthdayRecord(person: profile.person, dateSpec: $0) }
            merged.records = (appleRecords + localRecords).sorted { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.id < rhs.id
            }
            return merged
        }
    }

    private func observeContactsChanges() {
        contactsChangeObserver = NotificationCenter.default.addObserver(
            forName: ContactSyncService.didChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleContactsRefreshFromExternalChange()
            }
        }
    }

    private func scheduleContactsRefreshFromExternalChange() {
        guard permissionState == .authorized || permissionState == .limited else { return }
        contactsRefreshTask?.cancel()
        contactsRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await refreshContacts()
        }
    }

    private static func birthdaySignature(for profiles: [ContactBirthdayProfile]) -> Int {
        var hasher = Hasher()
        for profile in profiles {
            for record in profile.records {
                hasher.combine(record.id)
                hasher.combine(record.contactName)
                hasher.combine(record.organizationName)
                hasher.combine(record.kind)
                hasher.combine(record.year)
                hasher.combine(record.month)
                hasher.combine(record.day)
                hasher.combine(record.isLeapMonth)
            }
        }
        return hasher.finalize()
    }

    func refreshContacts() async {
        permissionState = contactSyncService.authorizationStatus
        guard permissionState == .authorized || permissionState == .limited else {
            clearContactData()
            selection = .permissions
            return
        }

        isLoading = true
        let progressRequestID = derivedRequestID
        startCalculationProgress(message: "Reading macOS Contacts")
        defer { isLoading = false }

        do {
            let snapshot = try await contactSyncService.refreshSnapshot(
                fieldAccessLevel: contactFieldAccessLevel,
                accessScope: contactAccessScope
            )
            applyContactSnapshot(snapshot)
            if derivedRequestID == progressRequestID {
                finishCalculationProgress(requestID: progressRequestID)
            }
            if selection == .permissions {
                selection = .calendar
            }
        } catch {
            if derivedRequestID == progressRequestID {
                finishCalculationProgress(requestID: progressRequestID)
            }
            errorMessage = error.localizedDescription
        }
    }

    func requestContactsAccess() async {
        do {
            _ = try await contactSyncService.requestAccess()
            await refreshContacts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openContactsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 跳转到联系人页并聚焦指定联系人（生日条目点击跳转，见设计文档 §6.3）
    func focusContact(_ contactID: String) {
        contactSearchText = ""
        selectedContactID = contactID
        selection = .contacts
    }

    func records(on date: Date) -> [BirthdayOccurrence] {
        cachedRecords(on: date)
    }

    func filteredRecords(on date: Date) -> [BirthdayOccurrence] {
        let key = dayKey(date)
        return visibleFilteredOccurrencesByDay[key] ?? []
    }

    private func cachedRecords(on date: Date) -> [BirthdayOccurrence] {
        visibleOccurrencesByDay[dayKey(date)] ?? []
    }

    private func dayKey(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func rebuildContactProjection() {
        let projection = contactListProjection.snapshot(
            profiles: profiles,
            grouping: contactGrouping,
            accessScope: contactAccessScope,
            selectedCollectionID: selectedContactCollectionID,
            searchText: contactSearchText,
            language: language,
            noBirthdaysText: l10n(.noBirthdays),
            todayText: l10n(.today),
            upcomingOccurrencesByContactID: Dictionary(
                cachedUpcomingOccurrences.map { ($0.record.contactID, $0) },
                uniquingKeysWith: { lhs, rhs in lhs.date <= rhs.date ? lhs : rhs }
            )
        )
        contactCollectionSections = projection.collectionSections
        contactListSections = projection.contactSections
        visibleContactCount = projection.visibleContactCount
        let visibleIDs = projection.contactSections.flatMap { $0.rows.map(\.id) }
        filteredProfiles = visibleIDs.compactMap { profileByID[$0] }
        selectedContactIDsForDeletion.formIntersection(Set(visibleIDs))
    }

    private func loadCachedContactSnapshot() async {
        guard let snapshot = await contactSyncService.cachedSnapshot(
            fieldAccessLevel: contactFieldAccessLevel,
            accessScope: contactAccessScope
        ) else { return }
        guard profiles.isEmpty else { return }
        applyContactSnapshot(snapshot)
    }

    private func clearContactData() {
        guard !profiles.isEmpty || !allRecords.isEmpty || contactGrouping != .empty else { return }
        profiles = []
        filteredProfiles = []
        profileByID = [:]
        selectedContactID = nil
        selectedContactCollectionID = ContactCollectionIdentifier.all
        contactGrouping = .empty
        contactCollectionSections = []
        contactListSections = []
        visibleContactCount = 0
        extendedProfilesByID = [:]
        selectedContactIDsForDeletion = []
        isContactSelectionMode = false
        birthdayRecordSignature = 0
        dataGeneration += 1
        scheduleDerivedDataRebuild(message: "Clearing contacts")
    }

    private func isContactCollectionSelectable(_ collectionID: String) -> Bool {
        guard collectionID != ContactCollectionIdentifier.all else { return true }
        guard contactAccessScope.mode == .selectedGroups else {
            return contactGrouping.contactIDsByCollectionID[collectionID] != nil
        }
        if collectionID == ContactCollectionIdentifier.ungrouped {
            return contactAccessScope.includeUngroupedContacts
        }
        let prefix = "group:"
        if collectionID.hasPrefix(prefix) {
            let groupID = String(collectionID.dropFirst(prefix.count))
            return contactAccessScope.allowedGroupIDs.contains(groupID)
        }
        return false
    }

    private func updateContactAccessScope(_ nextScope: ContactAccessScope) {
        let availableGroupIDs = Set(contactGrouping.groups.map(\.id))
        let scoped = contactGrouping.groups.isEmpty ? nextScope : nextScope.pruned(availableGroupIDs: availableGroupIDs)
        guard scoped != contactAccessScope else { return }

        contactAccessScope = scoped
        Self.saveContactAccessScope(scoped)
        selectedContactCollectionID = ContactCollectionIdentifier.all
        exitContactSelectionMode()

        guard permissionState == .authorized || permissionState == .limited else {
            rebuildContactProjection()
            scheduleDerivedDataRebuild(message: "Updating contact groups")
            return
        }

        Task { await refreshContacts() }
    }

    func setContactAccessMode(_ mode: ContactAccessScope.Mode) {
        var scope = contactAccessScope
        scope.mode = mode
        if mode == .selectedGroups, scope.allowedGroupIDs.isEmpty, !contactGrouping.groups.isEmpty {
            scope.allowedGroupIDs = Set(contactGrouping.groups.map(\.id))
        }
        updateContactAccessScope(scope)
    }

    func setContactAccessGroup(_ groupID: String, isAllowed: Bool) {
        var scope = contactAccessScope
        scope.mode = .selectedGroups
        if isAllowed {
            scope.allowedGroupIDs.insert(groupID)
        } else {
            scope.allowedGroupIDs.remove(groupID)
        }
        updateContactAccessScope(scope)
    }

    func setIncludeUngroupedContacts(_ include: Bool) {
        var scope = contactAccessScope
        scope.mode = .selectedGroups
        scope.includeUngroupedContacts = include
        updateContactAccessScope(scope)
    }

    func selectAllContactAccessGroups() {
        updateContactAccessScope(ContactAccessScope(
            mode: .selectedGroups,
            allowedGroupIDs: Set(contactGrouping.groups.map(\.id)),
            includeUngroupedContacts: true
        ))
    }

    func clearContactAccessGroups() {
        updateContactAccessScope(ContactAccessScope(
            mode: .selectedGroups,
            allowedGroupIDs: [],
            includeUngroupedContacts: false
        ))
    }

    private func loadLocalBirthdaySpecs() async {
        let specsByPersonID = await localBirthdayStore.loadAll()
        await MainActor.run {
            self.localDateSpecsByPersonID = specsByPersonID
            guard !self.profiles.isEmpty else { return }
            self.profiles = self.profilesByApplyingLocalSpecs(to: self.profiles)
            self.profileByID = Dictionary(uniqueKeysWithValues: self.profiles.map { ($0.id, $0) })
            self.rebuildContactProjection()
            self.scheduleDerivedDataRebuild(message: "Calculating birthdays")
        }
    }

    func scheduleSave(contactID: String, draft: BirthdayEditDraft) {
        guard let payload = draft.payload(personID: contactID) else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            await save(contactID: contactID, payload: payload)
        }
    }

    func save(contactID: String, payload: BirthdayEditPayload) async {
        do {
            await localBirthdayStore.saveLocalOnlySpecs(payload.localOnlyDateSpecs, for: contactID)
            localDateSpecsByPersonID[contactID] = payload.localOnlyDateSpecs
            try await contactSyncService.saveBirthdays(contactID: contactID, payload: payload)
            toast(L10n(language: language)(.written))
            await refreshContacts()
        } catch {
            errorMessage = L10n(language: language)(.saveFailed)
        }
    }

    func enterContactSelectionMode() {
        isContactSelectionMode = true
        selectedContactIDsForDeletion = []
    }

    func exitContactSelectionMode() {
        isContactSelectionMode = false
        selectedContactIDsForDeletion = []
    }

    func toggleContactDeletionSelection(_ contactID: String) {
        if selectedContactIDsForDeletion.contains(contactID) {
            selectedContactIDsForDeletion.remove(contactID)
        } else {
            selectedContactIDsForDeletion.insert(contactID)
        }
    }

    func selectAllVisibleContactsForDeletion() {
        selectedContactIDsForDeletion = Set(contactListSections.flatMap { $0.rows.map(\.id) })
    }

    func deleteSelectedContacts() async {
        let contactIDs = selectedContactIDsForDeletion
        guard !contactIDs.isEmpty, !isDeletingContacts else { return }

        isDeletingContacts = true
        defer { isDeletingContacts = false }

        do {
            try await contactSyncService.deleteContacts(contactIDs: Array(contactIDs))
            await localBirthdayStore.deleteLocalOnlySpecs(for: contactIDs)
            for contactID in contactIDs {
                localDateSpecsByPersonID[contactID] = nil
            }
            if let selectedContactID, contactIDs.contains(selectedContactID) {
                self.selectedContactID = nil
            }
            exitContactSelectionMode()
            toast(L10n(language: language)(.contactsDeleted))
            await refreshContacts()
        } catch {
            errorMessage = L10n(language: language)(.deleteContactsFailed)
        }
    }

    func convertVoiceText() {
        guard let parsed = parser.parse(voiceText) else {
            voiceResult = L10n(language: language)(.invalidDatePhrase)
            return
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: parsed.calendarKind.calendarIdentifier)
        components.year = parsed.year
        components.month = parsed.month
        components.day = parsed.day
        components.isLeapMonth = parsed.isLeapMonth
        let record = BirthdayRecord(
            contactID: "voice",
            contactName: L10n(language: language)(.voiceInput),
            organizationName: "",
            kind: parsed.calendarKind,
            components: components
        )

        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        guard let date = resolver.occurrence(for: record, inGregorianYear: year) else {
            voiceResult = L10n(language: language)(.invalidDatePhrase)
            return
        }

        let original = formatter.originalDate(record, locale: language.coreLocale)
        let converted = formatter.occurrenceDate(date, locale: language.coreLocale)
        voiceResult = "\(formatter.calendarName(parsed.calendarKind, locale: language.coreLocale)) \(original) → \(converted)"
    }

    func toggleVoiceInput() async {
        if isListening {
            voiceInput.stop()
            isListening = false
            convertVoiceText()
            return
        }

        do {
            isListening = true
            try await voiceInput.start(locale: Locale(identifier: language.coreLocale.rawValue)) { [weak self] text in
                self?.voiceText = text
            }
        } catch {
            isListening = false
            errorMessage = error.localizedDescription
        }
    }

    func toast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private static func loadContactFieldAccessLevel() -> ContactFieldAccessLevel {
        let rawValue = UserDefaults.standard.string(forKey: "contactFieldAccessLevel") ?? ""
        return ContactFieldAccessLevel(rawValue: rawValue) ?? .birthdayOnly
    }

    private static func saveContactFieldAccessLevel(_ level: ContactFieldAccessLevel) {
        UserDefaults.standard.set(level.rawValue, forKey: "contactFieldAccessLevel")
    }

    private static func loadContactAccessScope() -> ContactAccessScope {
        guard let data = UserDefaults.standard.data(forKey: "contactAccessScope") else {
            return .all
        }
        return (try? JSONDecoder().decode(ContactAccessScope.self, from: data)) ?? .all
    }

    private static func saveContactAccessScope(_ scope: ContactAccessScope) {
        guard let data = try? JSONEncoder().encode(scope) else { return }
        UserDefaults.standard.set(data, forKey: "contactAccessScope")
    }
}

struct BirthdayEditDraft: Equatable {
    var entries: [BirthdayEditEntry]

    init(profile: ContactBirthdayProfile) {
        entries = profile.records.map(BirthdayEditEntry.init(record:))
    }

    mutating func addEntry(personID: String, kind: BirthdayCalendarKind = .gregorian) {
        entries.append(BirthdayEditEntry(personID: personID, kind: kind))
    }

    mutating func removeEntry(id: String) {
        entries.removeAll { $0.id == id }
    }

    func payload(personID: String) -> BirthdayEditPayload? {
        let parsed = entries.map { entry in
            (entry: entry, spec: entry.dateSpec(personID: personID))
        }
        guard parsed.allSatisfy({ $0.spec != nil }) else {
            return nil
        }
        let specs = parsed.compactMap(\.spec)

        let appleGregorian = specs.first {
            $0.source == .appleBirthday && $0.kind == .gregorian
        }
        let appleNonGregorian = specs.first {
            $0.source == .appleNonGregorianBirthday && $0.kind != .gregorian
        }
        let appleSpecIDs = Set([appleGregorian?.id, appleNonGregorian?.id].compactMap { $0 })
        let localOnlySpecs = specs.filter { !appleSpecIDs.contains($0.id) }

        return BirthdayEditPayload(
            gregorian: appleGregorian?.components,
            nonGregorianKind: appleNonGregorian?.kind,
            nonGregorian: appleNonGregorian?.components,
            localOnlyDateSpecs: localOnlySpecs
        )
    }
}

struct BirthdayEditEntry: Identifiable, Equatable {
    var id: String
    var kind: BirthdayCalendarKind
    var year: String
    var month: String
    var day: String
    var isLeapMonth: Bool
    var source: BirthdayDateSpecSource

    init(record: BirthdayRecord) {
        id = record.id
        kind = record.kind
        year = record.year.map(String.init) ?? ""
        month = record.month.map(String.init) ?? ""
        day = record.day.map(String.init) ?? ""
        isLeapMonth = record.isLeapMonth
        if record.source == .local, !record.id.hasPrefix("local:") {
            source = record.kind == .gregorian ? .appleBirthday : .appleNonGregorianBirthday
        } else {
            source = record.source
        }
    }

    init(personID: String, kind: BirthdayCalendarKind) {
        id = "local:\(personID):\(UUID().uuidString)"
        self.kind = kind
        year = ""
        month = ""
        day = ""
        isLeapMonth = false
        source = .local
    }

    func dateSpec(personID: String) -> BirthdayDateSpec? {
        guard let monthValue = Int(month), let dayValue = Int(day),
              (1...13).contains(monthValue), (1...31).contains(dayValue)
        else { return nil }

        var value = DateComponents()
        value.calendar = Calendar(identifier: kind.calendarIdentifier)
        value.year = Int(year)
        value.month = monthValue
        value.day = dayValue
        if kind.supportsLeapMonth {
            value.isLeapMonth = isLeapMonth
        }

        return BirthdayDateSpec(
            id: id,
            personID: personID,
            kind: kind,
            components: value,
            source: source,
            syncPolicy: source == .local ? .localOnly : .writeBackToApple
        )
    }
}

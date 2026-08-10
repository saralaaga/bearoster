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

struct BirthdayMonthGroup: Identifiable, Hashable, Sendable {
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

    private(set) var allRecords: [BirthdayRecord] = []
    private(set) var filteredRecords: [BirthdayRecord] = []
    private(set) var filteredRecordOccurrences: [BirthdayOccurrence] = []
    private(set) var filteredRecordGroups: [BirthdayMonthGroup] = []
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
        Task { await loadCachedContactSnapshot() }
    }

    var selectedProfile: ContactBirthdayProfile? {
        guard let selectedContactID else { return filteredProfiles.first }
        return profileByID[selectedContactID]
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
        profiles = snapshot.profiles
        profileByID = Dictionary(uniqueKeysWithValues: snapshot.profiles.map { ($0.id, $0) })
        contactGrouping = snapshot.grouping
        extendedProfilesByID = snapshot.extendedProfilesByID
        if contactGrouping.contactIDsByCollectionID[selectedContactCollectionID] == nil {
            selectedContactCollectionID = ContactCollectionIdentifier.all
        }
        rebuildContactProjection()

        if selectedContactID == nil {
            selectedContactID = filteredProfiles.first?.id ?? snapshot.profiles.first?.id
        } else if let currentSelectedContactID = selectedContactID, profileByID[currentSelectedContactID] == nil {
            selectedContactID = filteredProfiles.first?.id ?? snapshot.profiles.first?.id
        }

        let nextSignature = Self.birthdaySignature(for: snapshot.profiles)
        guard nextSignature != birthdayRecordSignature else { return }
        birthdayRecordSignature = nextSignature
        dataGeneration += 1
        scheduleDerivedDataRebuild(message: "Calculating birthdays")
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
            selection = .permissions
            return
        }

        isLoading = true
        let progressRequestID = derivedRequestID
        startCalculationProgress(message: "Reading macOS Contacts")
        defer { isLoading = false }

        do {
            let snapshot = try await contactSyncService.refreshSnapshot(fieldAccessLevel: contactFieldAccessLevel)
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
    }

    private func loadCachedContactSnapshot() async {
        guard let snapshot = await contactSyncService.cachedSnapshot(fieldAccessLevel: contactFieldAccessLevel) else { return }
        guard profiles.isEmpty else { return }
        applyContactSnapshot(snapshot)
    }

    func scheduleSave(contactID: String, draft: BirthdayEditDraft) {
        guard let payload = draft.payload else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            await save(contactID: contactID, payload: payload)
        }
    }

    func save(contactID: String, payload: BirthdayEditPayload) async {
        do {
            try await contactSyncService.saveBirthdays(contactID: contactID, payload: payload)
            toast(L10n(language: language)(.written))
            await refreshContacts()
        } catch {
            errorMessage = L10n(language: language)(.saveFailed)
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
}

struct BirthdayEditDraft: Equatable {
    var gregorianYear = ""
    var gregorianMonth = ""
    var gregorianDay = ""
    var nonGregorianKind: BirthdayCalendarKind?
    var nonGregorianYear = ""
    var nonGregorianMonth = ""
    var nonGregorianDay = ""
    var isLeapMonth = false

    init(profile: ContactBirthdayProfile) {
        let gregorian = profile.records.first { $0.kind == .gregorian }
        gregorianYear = gregorian?.year.map(String.init) ?? ""
        gregorianMonth = gregorian?.month.map(String.init) ?? ""
        gregorianDay = gregorian?.day.map(String.init) ?? ""

        let alternate = profile.records.first { $0.kind != .gregorian }
        nonGregorianKind = alternate?.kind
        nonGregorianYear = alternate?.year.map(String.init) ?? ""
        nonGregorianMonth = alternate?.month.map(String.init) ?? ""
        nonGregorianDay = alternate?.day.map(String.init) ?? ""
        isLeapMonth = alternate?.isLeapMonth ?? false
    }

    var payload: BirthdayEditPayload? {
        guard case let .valid(gregorian) = parsedComponents(year: gregorianYear, month: gregorianMonth, day: gregorianDay, kind: .gregorian),
              let alternate = alternatePayload
        else {
            return nil
        }
        return BirthdayEditPayload(
            gregorian: gregorian,
            nonGregorianKind: alternate.kind,
            nonGregorian: alternate.components
        )
    }

    private var alternatePayload: (kind: BirthdayCalendarKind?, components: DateComponents?)? {
        guard let nonGregorianKind else {
            return (nil, nil)
        }
        guard case let .valid(components) = parsedComponents(
            year: nonGregorianYear,
            month: nonGregorianMonth,
            day: nonGregorianDay,
            kind: nonGregorianKind,
            isLeapMonth: isLeapMonth
        ) else { return nil }
        return (nonGregorianKind, components)
    }

    private enum ComponentParse {
        case valid(DateComponents?)
        case invalid
    }

    private func parsedComponents(
        year: String,
        month: String,
        day: String,
        kind: BirthdayCalendarKind,
        isLeapMonth: Bool = false
    ) -> ComponentParse {
        if year.isEmpty, month.isEmpty, day.isEmpty {
            return .valid(nil)
        }

        guard let monthValue = Int(month), let dayValue = Int(day),
              (1...13).contains(monthValue), (1...31).contains(dayValue)
        else { return .invalid }

        var value = DateComponents()
        value.calendar = Calendar(identifier: kind.calendarIdentifier)
        value.year = Int(year)
        value.month = monthValue
        value.day = dayValue
        if kind.supportsLeapMonth {
            value.isLeapMonth = isLeapMonth
        }
        return .valid(value)
    }
}

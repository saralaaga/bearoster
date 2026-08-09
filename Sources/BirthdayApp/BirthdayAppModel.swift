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

enum BirthdaySort: String, CaseIterable, Identifiable {
    case next
    case name
    case age
    case calendar

    var id: String { rawValue }
}

@MainActor
@Observable
final class BirthdayAppModel {
    var selection: SidebarSelection = .permissions
    var permissionState: ContactsPermissionState = .notDetermined
    var profiles: [ContactBirthdayProfile] = [] {
        didSet { rebuildDerivedData() }
    }
    var selectedContactID: String?
    var searchText = "" {
        didSet {
            rebuildFilteredRecords()
            rebuildVisibleOccurrences()
        }
    }
    var contactSearchText = "" {
        didSet { rebuildFilteredProfiles() }
    }
    var selectedDate = Date() {
        didSet { selectedDateOccurrences = records(on: selectedDate) }
    }
    var visibleMonth = Date() {
        didSet { rebuildVisibleOccurrences() }
    }
    var filter: BirthdayCalendarKind? {
        didSet { rebuildFilteredRecords() }
    }
    var sort: BirthdaySort = .next {
        didSet { rebuildFilteredRecords() }
    }
    var isLoading = false
    var errorMessage: String?
    var toastMessage: String?
    var language: AppLanguage = .system
    var showAge = true
    var upcomingRange = 30 {
        didSet { rebuildUpcomingOccurrences() }
    }
    var voiceText = ""
    var voiceResult: String?
    var isListening = false

    private(set) var allRecords: [BirthdayRecord] = []
    private(set) var filteredRecords: [BirthdayRecord] = []
    private(set) var filteredRecordOccurrences: [BirthdayOccurrence] = []
    private(set) var filteredProfiles: [ContactBirthdayProfile] = []
    private(set) var cachedUpcomingOccurrences: [BirthdayOccurrence] = []
    private(set) var selectedDateOccurrences: [BirthdayOccurrence] = []

    let formatter = CalendarFormattingService()
    let resolver = BirthdayOccurrenceResolver()
    let parser = DatePhraseParser()

    private let contactsRepository = ContactsRepository()
    private let voiceInput = VoiceInputService()
    private var saveTask: Task<Void, Never>?
    private var visibleOccurrencesByDay: [Date: [BirthdayOccurrence]] = [:]
    private var visibleFilteredOccurrencesByDay: [Date: [BirthdayOccurrence]] = [:]

    var l10n: L10n { L10n(language: language) }

    var selectedProfile: ContactBirthdayProfile? {
        guard let selectedContactID else { return filteredProfiles.first }
        return profiles.first { $0.id == selectedContactID }
    }

    private func rebuildDerivedData() {
        allRecords = profiles.flatMap(\.records)
        rebuildFilteredRecords()
        rebuildFilteredProfiles()
        rebuildUpcomingOccurrences()
        rebuildVisibleOccurrences()
        selectedDateOccurrences = records(on: selectedDate)
    }

    private func rebuildFilteredRecords() {
        var records = allRecords
        if let filter {
            records = records.filter { $0.kind == filter }
        }
        if !searchText.isEmpty {
            records = records.filter { $0.contactName.localizedCaseInsensitiveContains(searchText) }
        }
        let now = Date()
        switch sort {
        case .next:
            records.sort {
                let lhs = resolver.nextOccurrence(for: $0, after: now)?.date ?? .distantFuture
                let rhs = resolver.nextOccurrence(for: $1, after: now)?.date ?? .distantFuture
                return lhs < rhs
            }
        case .name:
            records.sort { $0.contactName.localizedStandardCompare($1.contactName) == .orderedAscending }
        case .age:
            records.sort { ($0.year ?? Int.max) < ($1.year ?? Int.max) }
        case .calendar:
            records.sort { $0.kind.rawValue < $1.kind.rawValue }
        }
        filteredRecords = records
        filteredRecordOccurrences = records.compactMap { resolver.nextOccurrence(for: $0, after: now) }
            .sorted { lhs, rhs in
                lhs.date == rhs.date ? lhs.record.contactName < rhs.record.contactName : lhs.date < rhs.date
            }
    }

    private func rebuildFilteredProfiles() {
        guard !contactSearchText.isEmpty else {
            filteredProfiles = profiles
            return
        }
        filteredProfiles = profiles.filter { $0.displayName.localizedCaseInsensitiveContains(contactSearchText) }
    }

    private func rebuildUpcomingOccurrences() {
        let now = Date()
        cachedUpcomingOccurrences = allRecords.compactMap { resolver.nextOccurrence(for: $0, after: now) }
            .filter { resolver.daysUntil($0.date, from: now) <= upcomingRange }
            .sorted { $0.date == $1.date ? $0.record.contactName < $1.record.contactName : $0.date < $1.date }
    }

    private func rebuildVisibleOccurrences() {
        let days = visibleMonthDays()
        var occurrencesByDay: [Date: [BirthdayOccurrence]] = [:]
        var filteredByDay: [Date: [BirthdayOccurrence]] = [:]

        for day in days {
            let key = dayKey(day)
            let occurrences = resolver.occurrences(on: day, records: allRecords)
            occurrencesByDay[key] = occurrences
            filteredByDay[key] = searchText.isEmpty
                ? occurrences
                : occurrences.filter { $0.record.contactName.localizedCaseInsensitiveContains(searchText) }
        }

        visibleOccurrencesByDay = occurrencesByDay
        visibleFilteredOccurrencesByDay = filteredByDay
        selectedDateOccurrences = records(on: selectedDate)
    }

    private func visibleMonthDays() -> [Date] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: startOfMonth) - 1
        guard let start = calendar.date(byAdding: .day, value: -weekday, to: startOfMonth) else {
            return []
        }
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 31
        let cells = Int(ceil(Double(weekday + daysInMonth) / 7.0)) * 7
        return (0..<cells).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayKey(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    func refreshContacts() async {
        permissionState = contactsRepository.authorizationStatus
        guard permissionState == .authorized else {
            selection = .permissions
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            profiles = try contactsRepository.fetchProfiles()
            if selectedContactID == nil {
                selectedContactID = profiles.first?.id
            }
            if selection == .permissions {
                selection = .calendar
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestContactsAccess() async {
        do {
            _ = try await contactsRepository.requestAccess()
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
        let key = dayKey(date)
        return visibleOccurrencesByDay[key] ?? resolver.occurrences(on: date, records: allRecords)
    }

    func filteredRecords(on date: Date) -> [BirthdayOccurrence] {
        let key = dayKey(date)
        if let occurrences = visibleFilteredOccurrencesByDay[key] {
            return occurrences
        }
        let occurrences = records(on: date)
        return searchText.isEmpty
            ? occurrences
            : occurrences.filter { $0.record.contactName.localizedCaseInsensitiveContains(searchText) }
    }

    func upcomingOccurrences() -> [BirthdayOccurrence] {
        cachedUpcomingOccurrences
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
            try contactsRepository.saveBirthdays(contactID: contactID, payload: payload)
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

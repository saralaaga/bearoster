import RosterCore
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

package enum SidebarSelection: String, CaseIterable, Identifiable {
    case calendar
    case list
    case contacts
    case tags
    case sync
    case permissions

    package var id: String { rawValue }
}

package enum ContactBatchFillPolicy: String, CaseIterable, Identifiable, Sendable {
    case onlyEmpty
    case overwriteExisting

    package var id: String { rawValue }
}

package enum ContactBatchRenameMode: String, CaseIterable, Identifiable, Sendable {
    case replace
    case prefix
    case suffix

    package var id: String { rawValue }
}

package struct ContactBatchEditDraft: Equatable, Sendable {
    package var renameMode: ContactBatchRenameMode = .replace
    package var renameFind = ""
    package var renameReplacement = ""
    package var renamePrefix = ""
    package var renameSuffix = ""
    package var givenName = ""
    package var familyName = ""
    package var nickname = ""
    package var organizationName = ""
    package var departmentName = ""
    package var jobTitle = ""
    package var phoneNumbers = ""
    package var emailAddresses = ""
    package var postalAddresses = ""

    package init(
        renameMode: ContactBatchRenameMode = .replace,
        renameFind: String = "",
        renameReplacement: String = "",
        renamePrefix: String = "",
        renameSuffix: String = "",
        givenName: String = "",
        familyName: String = "",
        nickname: String = "",
        organizationName: String = "",
        departmentName: String = "",
        jobTitle: String = "",
        phoneNumbers: String = "",
        emailAddresses: String = "",
        postalAddresses: String = ""
    ) {
        self.renameMode = renameMode
        self.renameFind = renameFind
        self.renameReplacement = renameReplacement
        self.renamePrefix = renamePrefix
        self.renameSuffix = renameSuffix
        self.givenName = givenName
        self.familyName = familyName
        self.nickname = nickname
        self.organizationName = organizationName
        self.departmentName = departmentName
        self.jobTitle = jobTitle
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.postalAddresses = postalAddresses
    }
}

package enum RosterSort: String, CaseIterable, Identifiable, Sendable {
    case next
    case name
    case age
    case calendar

    package var id: String { rawValue }
}

package struct RosterRecordGroup: Identifiable, Hashable, Sendable {
    package let id: String
    package let title: String
    package let occurrences: [RosterOccurrence]
}

package struct RosterOccurrenceListItem: Identifiable, Hashable, Sendable {
    package let id: String
    package let contactID: String
    package let contactName: String
    package let tags: [ContactTag]
    package let kind: RosterCalendarKind
    package let kindTitle: String
    package let metaText: String
    package let daysUntil: Int
    package let daysUntilText: String
    package let isToday: Bool
    package let accessibilityLabel: String
}

package struct RosterOccurrenceListGroup: Identifiable, Hashable, Sendable {
    package let id: String
    package let title: String
    package let items: [RosterOccurrenceListItem]
}

@MainActor
@Observable
package final class RosterAppModel {
    package var selection: SidebarSelection = .permissions {
        didSet {
            guard selection != oldValue else { return }
            if selection == .contacts || selection == .tags {
                rebuildContactProjection()
            }
        }
    }
    package var permissionState: ContactsPermissionState = .notDetermined
    package var selectedContactID: String?
    package var searchText = "" {
        didSet {
            scheduleDerivedDataRebuild(message: "Searching roster data", debounceNanoseconds: 250_000_000)
        }
    }
    package var contactSearchText = "" {
        didSet {
            guard contactSearchText != oldValue else { return }
            guard selection == .contacts || selection == .tags else { return }
            rebuildContactProjection(debounceNanoseconds: 180_000_000)
        }
    }
    package var contactFilters: [ContactFilterCondition] = [] {
        didSet {
            guard contactFilters != oldValue else { return }
            guard selection == .contacts || selection == .tags else { return }
            rebuildContactProjection()
        }
    }
    package var contactFilterMatchMode: ContactFilterMatchMode = .all {
        didSet {
            guard contactFilterMatchMode != oldValue else { return }
            guard selection == .contacts || selection == .tags else { return }
            rebuildContactProjection()
        }
    }
    package var selectedDate = Date() {
        didSet { selectedDateOccurrences = cachedRecords(on: selectedDate) }
    }
    package var visibleMonth = Date() {
        didSet { scheduleDerivedDataRebuild(message: "Calculating month") }
    }
    package var filter: RosterCalendarKind? {
        didSet { scheduleDerivedDataRebuild(message: "Filtering roster data") }
    }
    package var sort: RosterSort = .next {
        didSet { scheduleDerivedDataRebuild(message: "Sorting roster data") }
    }
    package var isLoading = false
    package var errorMessage: String?
    package var toastMessage: String?
    package var language: AppLanguage = .system {
        didSet {
            rebuildContactProjection()
            scheduleDerivedDataRebuild(message: "Updating language")
        }
    }
    package var showAge = true
    package var upcomingRange = 30 {
        didSet { scheduleDerivedDataRebuild(message: "Calculating upcoming roster data") }
    }
    package var selectedContactCollectionID = ContactCollectionIdentifier.all {
        didSet {
            guard selectedContactCollectionID != oldValue else { return }
            guard selection == .contacts else { return }
            rebuildContactProjection()
        }
    }
    package var selectedTagsFilter: ContactTagFilter = .all {
        didSet {
            guard selectedTagsFilter != oldValue else { return }
            guard selection == .tags else { return }
            rebuildContactProjection()
        }
    }
    package var rosterTagFilter: ContactTagFilter = .all {
        didSet {
            scheduleDerivedDataRebuild(message: "Filtering roster data")
        }
    }
    package private(set) var contactAccessScope: ContactAccessScope = RosterAppModel.loadContactAccessScope()
    package var contactFieldAccessLevel: ContactFieldAccessLevel = RosterAppModel.loadContactFieldAccessLevel() {
        didSet {
            guard contactFieldAccessLevel != oldValue else { return }
            Self.saveContactFieldAccessLevel(contactFieldAccessLevel)
            Task { await refreshContacts() }
        }
    }
    package var voiceText = ""
    package var voiceResult: String?
    package var isListening = false
    package var isContactSelectionMode = false
    package var selectedContactIDs: Set<String> = []
    package var isShowingContactAssignmentTargets = false
    package var isDeletingContacts = false

    package private(set) var allRecords: [RosterRecord] = []
    package private(set) var filteredRecords: [RosterRecord] = []
    package private(set) var filteredRecordOccurrences: [RosterOccurrence] = []
    package private(set) var filteredRecordGroups: [RosterRecordGroup] = []
    package private(set) var filteredRecordListGroups: [RosterOccurrenceListGroup] = []
    package private(set) var profiles: [ContactRosterProfile] = []
    package private(set) var filteredProfiles: [ContactRosterProfile] = []
    package private(set) var contactGrouping: ContactGroupingSnapshot = .empty
    package private(set) var contactCollectionSections: [ContactCollectionSectionModel] = []
    package private(set) var contactListSections: [ContactListSectionModel] = []
    package private(set) var visibleContactCount = 0
    package private(set) var contactTags: [ContactTag] = [] {
        didSet {
            contactTagTree = ContactTagTree(tags: contactTags)
            contactTagsByID = Dictionary(uniqueKeysWithValues: contactTags.map { ($0.id, $0) })
        }
    }
    package private(set) var contactTagAssignmentsByContactID: [String: Set<String>] = [:]
    package private(set) var contactTagFilterOptions: [ContactTagSelectionOption] = []
    package private(set) var visibleTagContactCount = 0
    package private(set) var contactWritePolicy: ContactWritePolicy = .confirmBeforeWrite
    package private(set) var contactDraftsByID: [String: LocalContactDraft] = [:]
    package private(set) var contactOperationLog: [ContactOperationLog] = []
    package var expandedTagIDs: Set<String> = []
    package private(set) var extendedProfilesByID: [String: ContactExtendedProfile] = [:]
    package private(set) var cachedUpcomingOccurrences: [RosterOccurrence] = []
    package private(set) var selectedDateOccurrences: [RosterOccurrence] = []
    package private(set) var visibleMonthDates: [Date] = []
    package private(set) var visibleMonthTitle = ""
    package private(set) var weekdaySymbols: [String] = []
    package private(set) var calculationProgress: RosterCalculationProgress = .inactive

    package let formatter = CalendarFormattingService()
    package let resolver = RosterOccurrenceResolver()
    package let parser = DatePhraseParser()

    private let contactSyncService = ContactSyncService()
    private let localRosterStore = LocalRosterStore()
    private let contactTagStore = ContactTagStore()
    private let contactJournalStore = ContactOperationJournalStore()
    private let derivedDataWorker = RosterDerivedDataWorker()
    private let contactProjectionWorker = ContactListProjectionWorker()
    private let voiceInput = VoiceInputService()
    private let calendar = Calendar(identifier: .gregorian)
    private var saveTask: Task<Void, Never>?
    private var derivedDataTask: Task<Void, Never>?
    private var contactProjectionTask: Task<Void, Never>?
    private var contactsRefreshTask: Task<Void, Never>?
    private var contactAssignmentTargetTask: Task<Void, Never>?
    private var contactsChangeObserver: NSObjectProtocol?
    private var dataGeneration = 0
    private var derivedRequestID = 0
    private var contactProjectionRequestID = 0
    private var profileByID: [String: ContactRosterProfile] = [:]
    private var contactTagTree = ContactTagTree(tags: [])
    private var contactTagsByID: [String: ContactTag] = [:]
    private var contactTagCountsByFilterID: [String: Int] = [:]
    private var localDateSpecsByPersonID: [String: [RosterDateSpec]] = [:]
    private var rosterRecordSignature = 0
    private var calculationStartedAt: Date?
    private var visibleOccurrencesByDay: [Date: [RosterOccurrence]] = [:]
    private var visibleFilteredOccurrencesByDay: [Date: [RosterOccurrence]] = [:]
    private let e2eFixture: RosterE2EFixture?
    private var e2eFrames: [String: CGRect] = [:]

    package var l10n: L10n { L10n(language: language) }
    package var extendedContactFieldsEnabled: Bool {
        get { contactFieldAccessLevel == .extended }
        set { contactFieldAccessLevel = newValue ? .extended : .birthdayOnly }
    }

    package init(e2eFixture: RosterE2EFixture? = nil) {
        self.e2eFixture = e2eFixture
        observeContactsChanges()
        scheduleDerivedDataRebuild(message: "Preparing roster data", debounceNanoseconds: 150_000_000)
        if let e2eFixture {
            resetE2EArtifacts()
            applyE2EFixture(e2eFixture)
        } else {
            Task { await loadLocalRosterSpecs() }
            Task { await loadContactTags() }
            Task { await loadContactJournal() }
            Task { await loadCachedContactSnapshot() }
        }
    }

    package var selectedProfile: ContactRosterProfile? {
        guard !isContactSelectionMode else { return nil }
        guard let selectedContactID else { return filteredProfiles.first }
        return profileByID[selectedContactID]
    }

    package var selectedEditableProfiles: [ContactRosterProfile] {
        selectedContactIDs.compactMap { editableProfile(for: $0) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    package var selectedContactSelectionCount: Int {
        selectedContactIDs.count
    }

    package var isE2EEnabled: Bool {
        e2eFixture != nil
    }

    package var pendingContactOperationCount: Int {
        contactOperationLog.filter { $0.status == .pending }.count
    }

    package func editableProfile(for contactID: String) -> ContactRosterProfile? {
        contactDraftsByID[contactID]?.profile ?? profileByID[contactID]
    }

    package func profile(for contactID: String) -> ContactRosterProfile? {
        editableProfile(for: contactID)
    }

    package var failedContactOperationCount: Int {
        contactOperationLog.filter { $0.status == .failed }.count
    }

    package var conflictedContactOperationCount: Int {
        contactOperationLog.filter { $0.status == .conflict }.count
    }

    package var trashedContactCount: Int {
        contactDraftsByID.values.filter(\.isDeleted).count
    }

    private func scheduleDerivedDataRebuild(message: String, debounceNanoseconds: UInt64 = 0) {
        derivedRequestID += 1
        let requestID = derivedRequestID
        let request = RosterDerivedDataRequest(
            generation: dataGeneration,
            profiles: profiles,
            searchText: searchText,
            selectedDate: selectedDate,
            visibleMonth: visibleMonth,
            filter: filter,
            tagFilter: rosterTagFilter,
            contactTags: contactTags,
            contactTagAssignmentsByContactID: contactTagAssignmentsByContactID,
            sort: sort,
            language: language,
            showAge: showAge,
            openContactText: l10n(.openContact),
            todayText: l10n(.today),
            upcomingRange: upcomingRange
        )
        let worker = derivedDataWorker

        startCalculationProgress(message: localizedProgressMessage(message))
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

    private func applyDerivedDataSnapshot(_ snapshot: RosterDerivedDataSnapshot) {
        allRecords = snapshot.allRecords
        filteredRecords = snapshot.filteredRecords
        filteredRecordOccurrences = snapshot.filteredRecordOccurrences
        filteredRecordGroups = snapshot.filteredRecordGroups
        filteredRecordListGroups = snapshot.filteredRecordListGroups
        cachedUpcomingOccurrences = snapshot.cachedUpcomingOccurrences
        selectedDateOccurrences = snapshot.selectedDateOccurrences
        visibleMonthDates = snapshot.visibleMonthDates
        visibleMonthTitle = snapshot.visibleMonthTitle
        weekdaySymbols = snapshot.weekdaySymbols
        visibleOccurrencesByDay = snapshot.visibleOccurrencesByDay
        visibleFilteredOccurrencesByDay = snapshot.visibleFilteredOccurrencesByDay
        if selection == .contacts || selection == .tags {
            rebuildContactProjection()
        }
    }

    private func finishCalculationProgress(requestID: Int) {
        let minimumVisibleSeconds: TimeInterval = 0.15
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

    private func localizedProgressMessage(_ message: String) -> String {
        switch message {
        case "Preparing roster data", "Calculating roster data", "Calculating upcoming roster data":
            return l10n(.progressPreparing)
        case "Filtering roster data", "Searching roster data":
            return l10n(.progressFiltering)
        case "Sorting roster data":
            return l10n(.progressSorting)
        case "Updating language", "Updating local edits", "Updating contact groups", "Clearing contacts", "Restoring contact":
            return l10n(.progressUpdating)
        case "Reading macOS Contacts":
            return l10n(.progressReadingContacts)
        case "Calculating month":
            return l10n(.progressPreparing)
        default:
            return message
        }
    }

    private func startCalculationProgress(message: String) {
        calculationProgress = RosterCalculationProgress(
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

        markConflictsIfNeeded(using: snapshot)
        let mergedProfiles = profilesByApplyingLocalState(to: snapshot.profiles)
        contactGrouping = snapshot.grouping
        extendedProfilesByID = snapshot.extendedProfilesByID
        if !isContactCollectionSelectable(selectedContactCollectionID) {
            selectedContactCollectionID = ContactCollectionIdentifier.all
        }
        applyProfilesIfRosterChanged(mergedProfiles, message: "Calculating roster data", debounceNanoseconds: 150_000_000)

        if selectedContactID == nil {
            selectedContactID = filteredProfiles.first?.id ?? snapshot.profiles.first?.id
        } else if let currentSelectedContactID = selectedContactID, profileByID[currentSelectedContactID] == nil {
            selectedContactID = filteredProfiles.first?.id ?? snapshot.profiles.first?.id
        }
    }

    @discardableResult
    private func applyProfilesIfRosterChanged(
        _ nextProfiles: [ContactRosterProfile],
        message: String,
        debounceNanoseconds: UInt64 = 0
    ) -> Bool {
        profiles = nextProfiles
        profileByID = Dictionary(uniqueKeysWithValues: nextProfiles.map { ($0.id, $0) })
        rebuildContactProjection()

        let nextSignature = Self.rosterSignature(for: nextProfiles)
        guard nextSignature != rosterRecordSignature else { return false }
        rosterRecordSignature = nextSignature
        dataGeneration += 1
        scheduleDerivedDataRebuild(message: message, debounceNanoseconds: debounceNanoseconds)
        return true
    }

    private func applyE2EFixture(_ fixture: RosterE2EFixture) {
        permissionState = .authorized
        contactAccessScope = .all
        selectedContactCollectionID = ContactCollectionIdentifier.all
        selectedTagsFilter = .all
        contactTags = fixture.tags
        contactTagAssignmentsByContactID = fixture.assignmentsByContactID
        selection = fixture.initialSelection
        if let selectedDate = fixture.initialSelectedDate {
            self.selectedDate = selectedDate
        }
        expandedTagIDs = ["__tags_root__"]
        applyContactSnapshot(fixture.snapshot)
    }

    private func profilesByApplyingLocalState(to profiles: [ContactRosterProfile]) -> [ContactRosterProfile] {
        var mergedProfiles = profiles.compactMap { profile -> ContactRosterProfile? in
            if contactDraftsByID[profile.id]?.isDeleted == true {
                return nil
            }
            if let draft = contactDraftsByID[profile.id] {
                return draft.profile
            }

            var merged = profile
            let localSpecs = localDateSpecsByPersonID[profile.id] ?? []
            let localSpecIDs = Set(localSpecs.map(\.id))
            let appleRecords = profile.records.filter { !localSpecIDs.contains($0.id) }
            let localRecords = localSpecs.map { RosterRecord(person: profile.person, dateSpec: $0) }
            merged.records = (appleRecords + localRecords).sorted { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.id < rhs.id
            }
            return merged
        }

        let appleIDs = Set(profiles.map(\.id))
        let localOnlyProfiles = contactDraftsByID.values
            .filter { !$0.isDeleted && !appleIDs.contains($0.id) }
            .map(\.profile)
        mergedProfiles.append(contentsOf: localOnlyProfiles)
        return mergedProfiles.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
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

    private static func rosterSignature(for profiles: [ContactRosterProfile]) -> Int {
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

    package func refreshContacts() async {
        if let e2eFixture {
            applyE2EFixture(e2eFixture)
            return
        }

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

    package func requestContactsAccess() async {
        do {
            _ = try await contactSyncService.requestAccess()
            await refreshContacts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    package func openContactsSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    /// 跳转到联系人页并聚焦指定联系人（生日条目点击跳转，见设计文档 §6.3）
    package func focusContact(_ contactID: String) {
        contactSearchText = ""
        contactFilters = []
        selectedContactID = contactID
        selection = .contacts
    }

    package func addContactFilter(_ filter: ContactFilterCondition) {
        guard !contactFilters.contains(where: { $0.id == filter.id }) else { return }
        contactFilters.append(filter)
    }

    package func updateContactFilter(_ filter: ContactFilterCondition) {
        guard let index = contactFilters.firstIndex(where: { $0.id == filter.id }) else { return }
        contactFilters[index] = filter
    }

    package func removeContactFilter(_ filter: ContactFilterCondition) {
        contactFilters.removeAll { $0.id == filter.id }
    }

    package func clearContactFilters() {
        contactFilters = []
        contactFilterMatchMode = .all
    }

    package func selectTagFilter(_ filter: ContactTagFilter) {
        selectedTagsFilter = filter
        if !contactSearchText.isEmpty {
            contactSearchText = ""
        }
        selection = .tags
    }

    package func selectContactCollection(_ collectionID: String) {
        selectedContactCollectionID = collectionID
        selection = .contacts
    }

    package func createContactGroup(named name: String, inContainerID containerID: String) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let operation = ContactOperationLog(
            contactID: ContactCollectionIdentifier.container(containerID),
            appleContactID: nil,
            displayName: trimmedName,
            kind: .createGroup,
            summary: contactGroupCreateSummary(groupName: trimmedName),
            contactGroup: ContactGroupOperationPayload(containerID: containerID, groupID: nil, name: trimmedName)
        )
        await queueGroupOperation(operation)
    }

    package func deleteContactGroup(collectionID: String) async {
        guard let groupID = ContactCollectionIdentifier.groupID(from: collectionID) else { return }
        await deleteContactGroup(groupID: groupID)
    }

    package func deleteContactGroup(groupID: String) async {
        let groupName = contactGrouping.groups.first(where: { $0.id == groupID })?.name ?? l10n(.group)
        let operation = ContactOperationLog(
            contactID: ContactCollectionIdentifier.group(groupID),
            appleContactID: groupID,
            displayName: groupName,
            kind: .deleteGroup,
            summary: contactGroupDeleteSummary(groupName: groupName),
            contactGroup: ContactGroupOperationPayload(containerID: nil, groupID: groupID, name: groupName)
        )
        await queueGroupOperation(operation)
    }

    private func queueGroupOperation(_ operation: ContactOperationLog) async {
        contactOperationLog.insert(operation, at: 0)
        await contactJournalStore.appendOperation(operation)
        if contactWritePolicy == .automatic {
            await writeBack(operation)
        } else {
            toast(contactQueuedText(count: 1))
        }
    }

    package func toggleTagExpansion(_ tagID: String) {
        if expandedTagIDs.contains(tagID) {
            expandedTagIDs.remove(tagID)
        } else {
            expandedTagIDs.insert(tagID)
        }
    }

    package func records(on date: Date) -> [RosterOccurrence] {
        cachedRecords(on: date)
    }

    package func filteredRecords(on date: Date) -> [RosterOccurrence] {
        let key = dayKey(date)
        return visibleFilteredOccurrencesByDay[key] ?? []
    }

    private func cachedRecords(on date: Date) -> [RosterOccurrence] {
        visibleOccurrencesByDay[dayKey(date)] ?? []
    }

    private func dayKey(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func rebuildContactProjection(debounceNanoseconds: UInt64 = 0) {
        contactProjectionRequestID += 1
        let requestID = contactProjectionRequestID
        let request = ContactListProjectionRequest(
            profiles: profiles,
            grouping: contactGrouping,
            contactTags: contactTags,
            tagIDsByContactID: contactTagAssignmentsByContactID,
            accessScope: contactAccessScope,
            selectedCollectionID: selectedContactCollectionID,
            selectedTagFilter: selection == .tags ? selectedTagsFilter : nil,
            searchText: contactSearchText,
            contactFilters: contactFilters,
            contactFilterMatchMode: contactFilterMatchMode,
            language: language,
            noRostersText: l10n(.noRosters),
            todayText: l10n(.today),
            upcomingOccurrencesByContactID: Dictionary(
                cachedUpcomingOccurrences.map { ($0.record.contactID, $0) },
                uniquingKeysWith: { lhs, rhs in lhs.date <= rhs.date ? lhs : rhs }
            )
        )

        let worker = contactProjectionWorker
        contactProjectionTask?.cancel()
        contactProjectionTask = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
                guard !Task.isCancelled else { return }
            }

            let projection = await worker.snapshot(for: request)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.contactProjectionRequestID == requestID else { return }
                self.applyContactProjection(projection)
            }
        }
    }

    private func applyContactProjection(_ projection: ContactListProjectionSnapshot) {
        contactCollectionSections = projection.collectionSections
        contactListSections = projection.contactSections
        visibleContactCount = projection.visibleContactCount
        visibleTagContactCount = projection.visibleContactCount
        rebuildContactTagFilterOptions()
        let visibleIDs = projection.contactSections.flatMap { $0.rows.map(\.id) }
        filteredProfiles = visibleIDs.compactMap { profileByID[$0] }
        selectedContactIDs.formIntersection(Set(visibleIDs))
        recordE2EEvent("projection rows=\(visibleIDs.joined(separator: ",")) collections=\(projection.collectionSections.flatMap { $0.collections.map(\.id) }.joined(separator: ","))")
    }

    private func loadCachedContactSnapshot() async {
        guard let snapshot = await contactSyncService.cachedSnapshot(
            fieldAccessLevel: contactFieldAccessLevel,
            accessScope: contactAccessScope
        ) else { return }
        guard profiles.isEmpty else { return }
        applyContactSnapshot(snapshot)
    }

    private func loadContactJournal() async {
        let snapshot = await contactJournalStore.load()
        await MainActor.run {
            self.contactWritePolicy = snapshot.writePolicy
            self.contactDraftsByID = snapshot.draftsByContactID
            self.contactOperationLog = snapshot.operations
            guard !self.profiles.isEmpty else { return }
            self.applyProfilesIfRosterChanged(
                self.profilesByApplyingLocalState(to: self.profiles),
                message: "Updating local edits",
                debounceNanoseconds: 150_000_000
            )
        }
    }

    private func markConflictsIfNeeded(using snapshot: ContactDataSnapshot) {
        let pendingIDs = Set(contactOperationLog.filter { $0.status == .pending }.map(\.contactID))
        guard !pendingIDs.isEmpty else { return }

        let appleProfilesByID = Dictionary(uniqueKeysWithValues: snapshot.profiles.map { ($0.id, $0) })
        var changedOperations: [ContactOperationLog] = []
        for operation in contactOperationLog where operation.status == .pending {
            guard let draft = operation.draft,
                  let appleContactID = draft.appleContactID,
                  let appleProfile = appleProfilesByID[appleContactID]
            else { continue }

            let currentSignature = LocalContactDraft.signature(
                profile: appleProfile,
                extended: snapshot.extendedProfilesByID[appleContactID]
            )
            guard currentSignature != draft.baseSignature else { continue }

            var conflict = operation
            conflict.status = .conflict
            conflict.errorMessage = contactConflictText
            conflict.updatedAt = Date()
            changedOperations.append(conflict)
        }

        guard !changedOperations.isEmpty else { return }
        for operation in changedOperations {
            if let index = contactOperationLog.firstIndex(where: { $0.id == operation.id }) {
                contactOperationLog[index] = operation
            }
        }
        Task { await contactJournalStore.updateOperations(changedOperations) }
        errorMessage = contactConflictText
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
        selectedContactIDs = []
        isContactSelectionMode = false
        rosterRecordSignature = 0
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

    package func setContactAccessMode(_ mode: ContactAccessScope.Mode) {
        var scope = contactAccessScope
        scope.mode = mode
        if mode == .selectedGroups, scope.allowedGroupIDs.isEmpty, !contactGrouping.groups.isEmpty {
            scope.allowedGroupIDs = Set(contactGrouping.groups.map(\.id))
        }
        updateContactAccessScope(scope)
    }

    package func setContactAccessGroup(_ groupID: String, isAllowed: Bool) {
        var scope = contactAccessScope
        scope.mode = .selectedGroups
        if isAllowed {
            scope.allowedGroupIDs.insert(groupID)
        } else {
            scope.allowedGroupIDs.remove(groupID)
        }
        updateContactAccessScope(scope)
    }

    package func setIncludeUngroupedContacts(_ include: Bool) {
        var scope = contactAccessScope
        scope.mode = .selectedGroups
        scope.includeUngroupedContacts = include
        updateContactAccessScope(scope)
    }

    package func selectAllContactAccessGroups() {
        updateContactAccessScope(ContactAccessScope(
            mode: .selectedGroups,
            allowedGroupIDs: Set(contactGrouping.groups.map(\.id)),
            includeUngroupedContacts: true
        ))
    }

    package func clearContactAccessGroups() {
        updateContactAccessScope(ContactAccessScope(
            mode: .selectedGroups,
            allowedGroupIDs: [],
            includeUngroupedContacts: false
        ))
    }

    private func loadLocalRosterSpecs() async {
        let specsByPersonID = await localRosterStore.loadAll()
        await MainActor.run {
            self.localDateSpecsByPersonID = specsByPersonID
            guard !self.profiles.isEmpty else { return }
            self.applyProfilesIfRosterChanged(
                self.profilesByApplyingLocalState(to: self.profiles),
                message: "Calculating roster data",
                debounceNanoseconds: 150_000_000
            )
        }
    }

    private func loadContactTags() async {
        let snapshot = await contactTagStore.load()
        var loadedTags = snapshot.tags.sorted(by: Self.compareTags(_:_:))
        var loadedAssignments = Self.prunedAssignments(
            snapshot.assignmentsByContactID,
            keeping: Set(loadedTags.map(\.id))
        )
        let emptyTagIDs = ContactTagTree(tags: loadedTags).emptySubtreeTagIDs(assignmentsByContactID: loadedAssignments)
        if !emptyTagIDs.isEmpty {
            await contactTagStore.deleteTags(tagIDs: emptyTagIDs)
            loadedTags.removeAll { emptyTagIDs.contains($0.id) }
            loadedAssignments = Self.prunedAssignments(
                loadedAssignments,
                keeping: Set(loadedTags.map(\.id))
            )
        }

        self.contactTags = loadedTags
        self.contactTagAssignmentsByContactID = loadedAssignments
        if self.selection == .contacts || self.selection == .tags {
            self.rebuildContactProjection()
        } else {
            self.rebuildContactTagFilterOptions()
        }
        self.scheduleDerivedDataRebuild(message: "Filtering roster data")
    }

    private func rebuildContactTagFilterOptions() {
        contactTagFilterOptions = Self.tagFilterOptions(
            tags: contactTags,
            tree: contactTagTree,
            assignmentsByContactID: contactTagAssignmentsByContactID,
            visibleContactIDs: Set(profiles.map(\.id)),
            allText: l10n(.all),
            untaggedText: l10n(.untaggedContacts)
        )
        contactTagCountsByFilterID = Dictionary(uniqueKeysWithValues: contactTagFilterOptions.map { ($0.filter.cacheKey, $0.count) })
    }

    package func tags(for contactID: String) -> [ContactTag] {
        let tagIDs = contactTagAssignmentsByContactID[contactID] ?? []
        return tagIDs.compactMap { contactTagsByID[$0] }.sorted(by: Self.compareTags(_:_:))
    }

    package var contactTagTreeNodes: [ContactTagTreeNode] {
        contactTagTree.flattened
    }

    package func childTags(of tagID: String?) -> [ContactTag] {
        contactTagTree.children(of: tagID)
    }

    package func tagPath(for tagID: String) -> String {
        contactTagTree.displayPath(for: tagID)
    }

    package func tagAndDescendantIDs(for tagID: String) -> Set<String> {
        contactTagTree.tagAndDescendantIDs(for: tagID)
    }

    package var taggedContactCount: Int {
        Self.taggedContactCount(
            assignmentsByContactID: contactTagAssignmentsByContactID,
            visibleContactIDs: Set(profiles.map(\.id))
        )
    }

    package nonisolated static func taggedContactCount(
        assignmentsByContactID: [String: Set<String>],
        visibleContactIDs: Set<String>
    ) -> Int {
        assignmentsByContactID.filter { contactID, tagIDs in
            visibleContactIDs.contains(contactID) && !tagIDs.isEmpty
        }.count
    }

    package func contactCount(for filter: ContactTagFilter) -> Int {
        if let count = contactTagCountsByFilterID[filter.cacheKey] { return count }
        let visibleContactIDs = Set(profiles.map(\.id))
        let matchingTagIDs = filter.matchingTagIDs(in: contactTagTree)
        return visibleContactIDs.filter {
            filter.contains(
                contactID: $0,
                assignments: contactTagAssignmentsByContactID,
                matchingTagIDs: matchingTagIDs
            )
        }.count
    }

    package func createTag(name: String, parentTagID: String? = nil) async {
        _ = await ensureTag(named: name, parentTagID: parentTagID)
    }

    package func assignTags(tagIDs: Set<String>, to contactIDs: Set<String>) async {
        guard !tagIDs.isEmpty, !contactIDs.isEmpty else { return }
        await contactTagStore.assign(tagIDs: tagIDs, to: contactIDs)
        await MainActor.run {
            for contactID in contactIDs {
                self.contactTagAssignmentsByContactID[contactID, default: []].formUnion(tagIDs)
            }
            self.rebuildContactTagFilterOptions()
            self.rebuildContactProjection()
            self.scheduleDerivedDataRebuild(message: "Filtering roster data")
            self.toast(self.bulkTagToast(count: contactIDs.count))
        }
    }

    package func assignTags(named tagName: String, to contactIDs: Set<String>) async {
        guard let tag = await tagFromNewTagName(tagName) else { return }
        await assignTags(tagIDs: [tag.id], to: contactIDs)
    }

    package func assignTags(tagIDs: Set<String>, newTagName: String, to contactIDs: Set<String>) async {
        var ids = tagIDs
        if let tag = await tagFromNewTagName(newTagName) {
            ids.insert(tag.id)
        }
        await assignTags(tagIDs: ids, to: contactIDs)
    }

    package func replaceTags(for contactID: String, tagIDs: Set<String>) async {
        await contactTagStore.replaceAssignments(for: contactID, tagIDs: tagIDs)
        self.contactTagAssignmentsByContactID[contactID] = tagIDs.isEmpty ? nil : tagIDs
        await pruneEmptyContactTagsIfNeeded()
        self.rebuildContactTagFilterOptions()
        self.rebuildContactProjection()
        self.scheduleDerivedDataRebuild(message: "Filtering roster data")
    }

    package func replaceTags(for contactID: String, tagIDs: Set<String>, newTagName: String) async {
        var ids = tagIDs
        if let tag = await tagFromNewTagName(newTagName) {
            ids.insert(tag.id)
        }
        await replaceTags(for: contactID, tagIDs: ids)
    }

    package func deleteTagAndDescendants(_ tagID: String) async {
        let tagIDs = tagAndDescendantIDs(for: tagID)
        await contactTagStore.deleteTags(tagIDs: tagIDs)
        await MainActor.run {
            self.contactTags.removeAll { tagIDs.contains($0.id) }
            self.expandedTagIDs.subtract(tagIDs)
            self.contactTagAssignmentsByContactID = self.contactTagAssignmentsByContactID.compactMapValues { assignments in
                let remaining = assignments.subtracting(tagIDs)
                return remaining.isEmpty ? nil : remaining
            }
            if case let .tag(selectedID) = self.selectedTagsFilter, tagIDs.contains(selectedID) {
                self.selectedTagsFilter = .all
            }
            if case let .tag(selectedID) = self.rosterTagFilter, tagIDs.contains(selectedID) {
                self.rosterTagFilter = .all
            }
            self.rebuildContactTagFilterOptions()
            self.rebuildContactProjection()
            self.scheduleDerivedDataRebuild(message: "Filtering roster data")
        }
    }

    package func renameTag(_ tagID: String, name rawName: String) async {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = contactTags.firstIndex(where: { $0.id == tagID }) else { return }
        var tag = contactTags[index]
        tag.name = name
        tag.updatedAt = Date()
        await contactTagStore.saveTag(tag)
        await MainActor.run {
            self.contactTags[index] = tag
            self.contactTags.sort(by: Self.compareTags(_:_:))
            self.rebuildContactTagFilterOptions()
            self.rebuildContactProjection()
            self.scheduleDerivedDataRebuild(message: "Filtering roster data")
        }
    }

    package func cycleTagColor(_ tagID: String) async {
        guard let index = contactTags.firstIndex(where: { $0.id == tagID }) else { return }
        var tag = contactTags[index]
        let currentIndex = Self.defaultTagColors.firstIndex(of: tag.color) ?? -1
        tag.color = Self.defaultTagColors[(currentIndex + 1) % Self.defaultTagColors.count]
        tag.updatedAt = Date()
        await contactTagStore.saveTag(tag)
        await MainActor.run {
            self.contactTags[index] = tag
            self.rebuildContactTagFilterOptions()
            self.rebuildContactProjection()
            self.scheduleDerivedDataRebuild(message: "Filtering roster data")
        }
    }

    nonisolated static func tagPathComponents(from rawName: String) -> [String] {
        rawName
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func tagFromNewTagName(_ rawName: String) async -> ContactTag? {
        let components = Self.tagPathComponents(from: rawName)
        guard !components.isEmpty else { return nil }
        return await ensureTagPath(components)
    }

    private func ensureTagPath(_ names: [String]) async -> ContactTag? {
        var parentTagID: String?
        var tag: ContactTag?
        for name in names {
            tag = await ensureTag(named: name, parentTagID: parentTagID)
            parentTagID = tag?.id
        }
        return tag
    }

    private func ensureTag(named rawName: String, parentTagID: String? = nil) async -> ContactTag {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = contactTags.first(where: {
            $0.parentTagID == parentTagID && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return existing
        }

        let tag = ContactTag(
            name: name,
            color: Self.defaultTagColors[contactTags.count % Self.defaultTagColors.count],
            parentTagID: parentTagID,
            sortOrder: contactTags.count
        )
        await contactTagStore.saveTag(tag)
        await MainActor.run {
            self.contactTags.append(tag)
            self.contactTags.sort(by: Self.compareTags(_:_:))
            self.rebuildContactTagFilterOptions()
            self.rebuildContactProjection()
        }
        return tag
    }

    package func scheduleSave(contactID: String, draft: RosterEditDraft) {
        guard let payload = draft.payload(personID: contactID) else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            await save(contactID: contactID, payload: payload)
        }
    }

    package func save(contactID: String, payload: RosterEditPayload) async {
        guard let profile = profileByID[contactID] else { return }
        let birthdaySpecs = payload.journalRosterSpecs(personID: contactID)
        var draft = contactDraftsByID[contactID] ?? LocalContactDraft(
            profile: profile,
            extended: extendedProfilesByID[contactID],
            birthdaySpecs: birthdaySpecs
        )
        draft.birthdaySpecs = birthdaySpecs
        draft.displayName = profile.displayName
        draft.givenName = profile.givenName
        draft.familyName = profile.familyName
        draft.nickname = profile.nickname
        draft.organizationName = profile.organizationName
        draft.departmentName = profile.departmentName
        draft.jobTitle = profile.jobTitle
        draft.phoneNumbers = profile.phoneNumbers
        draft.emailAddresses = profile.emailAddresses
        draft.postalAddresses = profile.postalAddresses
        draft.imageData = profile.imageData
        draft.updatedAt = Date()
        draft.isDeleted = false
        draft.deletedAt = nil

        let operation = ContactOperationLog(
            contactID: contactID,
            appleContactID: draft.appleContactID,
            displayName: draft.displayName,
            kind: .update,
            summary: contactUpdateSummary(for: draft),
            fieldChanges: rosterChanges(previous: profile.dateSpecs, next: birthdaySpecs),
            draft: draft
        )

        await contactJournalStore.saveDraft(draft)
        await contactJournalStore.appendOperation(operation)
        await localRosterStore.saveLocalOnlySpecs(payload.localOnlyDateSpecs, for: contactID)

        contactDraftsByID[contactID] = draft
        contactOperationLog.insert(operation, at: 0)
        localDateSpecsByPersonID[contactID] = payload.localOnlyDateSpecs
        applyProfilesIfRosterChanged(profilesByApplyingLocalState(to: profiles), message: "Updating local edits")

        if contactWritePolicy == .automatic {
            await writeBack(operation)
        } else {
            toast(contactQueuedText(count: 1))
        }
    }

    package func save(contactID: String, draft editDraft: RosterEditDraft) async {
        guard let profile = profileByID[contactID],
              let updatedProfile = editDraft.profile(personID: contactID, fallback: profile)
        else { return }

        let birthdaySpecs = updatedProfile.dateSpecs
        var draft = contactDraftsByID[contactID] ?? LocalContactDraft(
            profile: profile,
            extended: extendedProfilesByID[contactID],
            birthdaySpecs: profile.dateSpecs
        )
        let previous = draft

        draft.displayName = updatedProfile.displayName
        draft.givenName = updatedProfile.givenName
        draft.familyName = updatedProfile.familyName
        draft.nickname = updatedProfile.nickname
        draft.organizationName = updatedProfile.organizationName
        draft.departmentName = updatedProfile.departmentName
        draft.jobTitle = updatedProfile.jobTitle
        draft.phoneNumbers = updatedProfile.phoneNumbers
        draft.emailAddresses = updatedProfile.emailAddresses
        draft.postalAddresses = updatedProfile.postalAddresses
        draft.birthdaySpecs = birthdaySpecs
        draft.imageData = updatedProfile.imageData
        draft.updatedAt = Date()
        draft.isDeleted = false
        draft.deletedAt = nil

        let operation = ContactOperationLog(
            contactID: contactID,
            appleContactID: draft.appleContactID,
            displayName: draft.displayName,
            kind: .update,
            summary: contactUpdateSummary(for: draft),
            fieldChanges: contactFieldChanges(previous: previous, next: draft),
            draft: draft
        )

        await contactJournalStore.saveDraft(draft)
        await contactJournalStore.appendOperation(operation)
        await localRosterStore.saveLocalOnlySpecs(editDraft.localOnlyDateSpecs(personID: contactID), for: contactID)

        contactDraftsByID[contactID] = draft
        contactOperationLog.insert(operation, at: 0)
        localDateSpecsByPersonID[contactID] = editDraft.localOnlyDateSpecs(personID: contactID)
        applyProfilesIfRosterChanged(profilesByApplyingLocalState(to: profiles), message: "Updating local edits")

        if contactWritePolicy == .automatic {
            await writeBack(operation)
        } else {
            toast(contactQueuedText(count: 1))
        }
    }

    package func applyBatchContactEdits(
        _ draft: ContactBatchEditDraft,
        fillPolicy: ContactBatchFillPolicy,
        contactIDs: Set<String>
    ) async {
        let ids = contactIDs.sorted()
        guard !ids.isEmpty else { return }

        var operations: [ContactOperationLog] = []
        let timestamp = Date()

        for contactID in ids {
            guard let profile = editableProfile(for: contactID) else { continue }
            var local = contactDraftsByID[contactID] ?? LocalContactDraft(
                profile: profile,
                extended: extendedProfilesByID[contactID],
                birthdaySpecs: profile.dateSpecs
            )
            let previous = local
            applyBatchDraft(draft, fillPolicy: fillPolicy, to: &local)
            local.updatedAt = timestamp
            local.isDeleted = false
            local.deletedAt = nil
            contactDraftsByID[contactID] = local
            await contactJournalStore.saveDraft(local)

            let operation = ContactOperationLog(
                contactID: contactID,
                appleContactID: local.appleContactID,
                displayName: local.displayName,
                kind: .update,
                summary: contactUpdateSummary(for: local),
                fieldChanges: contactFieldChanges(previous: previous, next: local),
                draft: local
            )
            contactOperationLog.insert(operation, at: 0)
            await contactJournalStore.appendOperation(operation)
            operations.append(operation)
        }

        guard !operations.isEmpty else { return }

        applyProfilesIfRosterChanged(profilesByApplyingLocalState(to: profiles), message: "Updating local edits")

        if contactWritePolicy == .automatic {
            for operation in operations {
                await writeBack(operation)
            }
        } else {
            toast(contactQueuedText(count: operations.count))
        }
    }

    package func enterContactSelectionMode() {
        isContactSelectionMode = true
        selectedContactIDs = []
    }

    package func exitContactSelectionMode() {
        isContactSelectionMode = false
        selectedContactIDs = []
    }

    package func toggleContactSelection(_ contactID: String) {
        if selectedContactIDs.contains(contactID) {
            selectedContactIDs.remove(contactID)
        } else {
            selectedContactIDs.insert(contactID)
        }
    }

    package func deleteSelectedContacts() async {
        let contactIDs = selectedContactIDs
        guard !contactIDs.isEmpty, !isDeletingContacts else { return }

        isDeletingContacts = true
        defer { isDeletingContacts = false }

        var operations: [ContactOperationLog] = []
        for contactID in contactIDs {
            guard let profile = profileByID[contactID] else { continue }
            var draft = contactDraftsByID[contactID] ?? LocalContactDraft(
                profile: profile,
                extended: extendedProfilesByID[contactID],
                birthdaySpecs: profile.dateSpecs
            )
            draft.isDeleted = true
            draft.deletedAt = Date()
            draft.updatedAt = Date()
            contactDraftsByID[contactID] = draft
            await contactJournalStore.saveDraft(draft)

            let operation = ContactOperationLog(
                contactID: contactID,
                appleContactID: draft.appleContactID,
                displayName: draft.displayName,
                kind: .delete,
                summary: contactDeleteSummary(for: draft),
                draft: draft
            )
            contactOperationLog.insert(operation, at: 0)
            await contactJournalStore.appendOperation(operation)
            operations.append(operation)
        }

        if let selectedContactID, contactIDs.contains(selectedContactID) {
            self.selectedContactID = nil
        }
        exitContactSelectionMode()
        applyProfilesIfRosterChanged(profilesByApplyingLocalState(to: profiles), message: "Updating local edits")

        if contactWritePolicy == .automatic {
            for operation in operations {
                await writeBack(operation)
            }
        } else {
            toast(contactQueuedText(count: operations.count))
        }
    }

    package func setContactWritePolicy(_ policy: ContactWritePolicy) {
        guard contactWritePolicy != policy else { return }
        contactWritePolicy = policy
        Task { await contactJournalStore.setWritePolicy(policy) }
        if policy == .automatic {
            Task { await writeBackPendingContactOperations() }
        }
    }

    package func writeBackPendingContactOperations() async {
        let pending = contactOperationLog
            .filter { $0.status == .pending }
            .sorted { $0.createdAt < $1.createdAt }
        guard !pending.isEmpty else { return }

        for operation in pending {
            await writeBack(operation)
        }
    }

    package func restoreContactFromTrash(_ contactID: String) async {
        guard var draft = contactDraftsByID[contactID], draft.isDeleted else { return }
        draft.isDeleted = false
        draft.deletedAt = nil
        draft.updatedAt = Date()
        contactDraftsByID[contactID] = draft
        await contactJournalStore.saveDraft(draft)

        let operation = ContactOperationLog(
            contactID: contactID,
            appleContactID: draft.appleContactID,
            displayName: draft.displayName,
            kind: .restore,
            status: .applied,
            summary: contactRestoreSummary(for: draft),
            draft: draft
        )
        contactOperationLog.insert(operation, at: 0)
        await contactJournalStore.appendOperation(operation)

        applyProfilesIfRosterChanged(profilesByApplyingLocalState(to: profiles + [draft.profile]), message: "Restoring contact")
        toast(contactRestoredText)
    }

    package func acceptMacOSVersion(for operationID: String) async {
        guard let operation = contactOperationLog.first(where: { $0.id == operationID }) else { return }
        await contactJournalStore.deleteDraft(contactID: operation.contactID)
        contactDraftsByID[operation.contactID] = nil

        var reverted = operation
        reverted.status = .reverted
        reverted.updatedAt = Date()
        contactOperationLog.replaceOrInsert(reverted)
        await contactJournalStore.updateOperation(reverted)
        await refreshContacts()
    }

    package func overwriteMacOSVersion(for operationID: String) async {
        guard let operation = contactOperationLog.first(where: { $0.id == operationID }) else { return }
        var pending = operation
        pending.status = .pending
        pending.errorMessage = nil
        pending.updatedAt = Date()
        contactOperationLog.replaceOrInsert(pending)
        await contactJournalStore.updateOperation(pending)
        await writeBack(pending)
    }

    private func writeBack(_ operation: ContactOperationLog) async {
        guard operation.status == .pending else { return }

        do {
            switch operation.kind {
            case .update, .restore:
                guard operation.appleContactID != nil else {
                    markOperation(operation, status: .failed, error: contactCreateUnsupportedText)
                    return
                }
                guard let draft = operation.draft else { return }
                try await contactSyncService.saveContact(
                    contactID: operation.contactID,
                    profile: draft.profile
                )
                await contactJournalStore.deleteDraft(contactID: operation.contactID)
                contactDraftsByID[operation.contactID] = nil
            case .delete:
                guard operation.appleContactID != nil else {
                    markOperation(operation, status: .failed, error: contactCreateUnsupportedText)
                    return
                }
                try await contactSyncService.deleteContacts(contactIDs: [operation.contactID])
                await localRosterStore.deleteLocalOnlySpecs(for: [operation.contactID])
                await contactTagStore.deleteAssignments(for: [operation.contactID])
                localDateSpecsByPersonID[operation.contactID] = nil
                contactTagAssignmentsByContactID[operation.contactID] = nil
            case .create:
                markOperation(operation, status: .failed, error: contactCreateUnsupportedText)
                return
            case .createGroup:
                guard let group = operation.contactGroup,
                      let containerID = group.containerID
                else { return }
                try await contactSyncService.createGroup(named: group.name, inContainerID: containerID)
            case .deleteGroup:
                guard let groupID = operation.contactGroup?.groupID else { return }
                if selectedContactCollectionID == ContactCollectionIdentifier.group(groupID) {
                    selectedContactCollectionID = ContactCollectionIdentifier.all
                }
                try await contactSyncService.deleteGroup(groupID: groupID)
            }

            markOperation(operation, status: .applied, error: nil)
            toast(L10n(language: language)(.written))
            await refreshContacts()
        } catch {
            markOperation(operation, status: .failed, error: error.localizedDescription)
            errorMessage = groupOperationKinds.contains(operation.kind)
                ? L10n(language: language)(.contactGroupEditFailed)
                : L10n(language: language)(.saveFailed)
        }
    }

    private func markOperation(_ operation: ContactOperationLog, status: ContactOperationStatus, error: String?) {
        var updated = operation
        updated.status = status
        updated.errorMessage = error
        updated.updatedAt = Date()
        contactOperationLog.replaceOrInsert(updated)
        Task { await contactJournalStore.updateOperation(updated) }
    }

    package func convertVoiceText() {
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
        let record = RosterRecord(
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

    package func toggleVoiceInput() async {
        if isListening {
            voiceInput.stop()
            isListening = false
            convertVoiceText()
            return
        }

        do {
            isListening = true
            try await voiceInput.start(locale: Locale(identifier: language.coreLocale.rawValue), language: language) { [weak self] text in
                self?.voiceText = text
            }
        } catch {
            isListening = false
            errorMessage = error.localizedDescription
        }
    }

    package func draggedContactIDs(for contactID: String) -> Set<String> {
        ContactDragSelectionResolver.draggedContactIDs(
            draggedContactID: contactID,
            selectedContactIDs: selectedContactIDs,
            isSelectionMode: isContactSelectionMode
        )
    }

    package func beginContactDrag() {
        isShowingContactAssignmentTargets = true
        recordE2EEvent("drag-began")
        contactAssignmentTargetTask?.cancel()
        contactAssignmentTargetTask = Task {
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.isShowingContactAssignmentTargets = false
            }
        }
    }

    package func recordE2EContactRowTap(_ contactID: String) {
        recordE2EEvent("row-tap contact=\(contactID)")
    }

    package func clearContactAssignmentTargets() {
        contactAssignmentTargetTask?.cancel()
        contactAssignmentTargetTask = nil
        isShowingContactAssignmentTargets = false
    }

    package func dragPayload(for contactID: String) -> ContactAssignmentDragPayload {
        return ContactAssignmentDragPayload(contactIDs: draggedContactIDs(for: contactID).sorted())
    }

    package func dragItemProvider(for contactID: String) -> NSItemProvider {
        let payload = dragPayload(for: contactID)
        let provider = NSItemProvider()
        if let data = try? JSONEncoder().encode(payload) {
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.rosterContactAssignmentPayload.identifier,
                visibility: .all
            ) { completion in
                completion(data, nil)
                return nil
            }
        }
        provider.registerObject(payload.contactIDs.joined(separator: ",") as NSString, visibility: .all)
        return provider
    }

    package func assignDroppedContacts(_ payloads: [ContactAssignmentDragPayload], toTagID tagID: String) {
        let contactIDs = ContactAssignmentTargetResolver.droppedContactIDs(from: payloads)
        guard !contactIDs.isEmpty else { return }
        clearContactAssignmentTargets()
        recordE2EEvent("tag-drop tag=\(tagID) contacts=\(contactIDs.sorted().joined(separator: ","))")
        Task {
            await assignTags(tagIDs: [tagID], to: contactIDs)
        }
    }

    package func assignDroppedContacts(from providers: [NSItemProvider], toTagID tagID: String) -> Bool {
        guard providers.contains(where: { provider in
            UTType.contactAssignmentDropTypes.contains {
                provider.hasItemConformingToTypeIdentifier($0.identifier)
            }
        }) else {
            return false
        }
        ContactAssignmentTargetResolver.loadDroppedContactIDs(from: providers) { [weak self] contactIDs in
            guard let self else { return }
            guard !contactIDs.isEmpty else { return }
            self.clearContactAssignmentTargets()
            self.recordE2EEvent("tag-drop tag=\(tagID) contacts=\(contactIDs.sorted().joined(separator: ","))")
            Task {
                await self.assignTags(tagIDs: [tagID], to: contactIDs)
            }
        }
        return true
    }

    package func assignDroppedContacts(_ payloads: [ContactAssignmentDragPayload], toGroupID groupID: String) {
        let contactIDs = ContactAssignmentTargetResolver.droppedContactIDs(from: payloads)
        guard !contactIDs.isEmpty else { return }
        clearContactAssignmentTargets()
        recordE2EEvent("group-drop group=\(groupID) contacts=\(contactIDs.sorted().joined(separator: ","))")
        Task {
            await moveContacts(contactIDs, toGroupID: groupID)
        }
    }

    package func assignDroppedContacts(from providers: [NSItemProvider], toGroupID groupID: String) -> Bool {
        guard providers.contains(where: { provider in
            UTType.contactAssignmentDropTypes.contains {
                provider.hasItemConformingToTypeIdentifier($0.identifier)
            }
        }) else {
            return false
        }
        ContactAssignmentTargetResolver.loadDroppedContactIDs(from: providers) { [weak self] contactIDs in
            guard let self else { return }
            guard !contactIDs.isEmpty else { return }
            self.clearContactAssignmentTargets()
            self.recordE2EEvent("group-drop group=\(groupID) contacts=\(contactIDs.sorted().joined(separator: ","))")
            Task {
                await self.moveContacts(contactIDs, toGroupID: groupID)
            }
        }
        return true
    }

    package func recordE2EFrame(identifier: String, screenRect: CGRect) {
        guard isE2EEnabled, !screenRect.isEmpty else { return }
        e2eFrames[identifier] = screenRect
        let lines = e2eFrames
            .sorted { $0.key < $1.key }
            .map { id, rect in
                "\(id)\t\(rect.minX)\t\(rect.minY)\t\(rect.width)\t\(rect.height)"
            }
            .joined(separator: "\n")
        try? "\(lines)\n".write(toFile: Self.e2eFramesPath, atomically: true, encoding: .utf8)
    }

    package func visibleGroupDropCollections() -> [ContactCollectionSummary] {
        ContactAssignmentTargetResolver.groupDropCollections(from: contactCollectionSections)
    }

    package func toast(_ message: String) {
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

    private func resetE2EArtifacts() {
        try? FileManager.default.removeItem(atPath: Self.e2eFramesPath)
        try? FileManager.default.removeItem(atPath: Self.e2eEventsPath)
    }

    private func recordE2EEvent(_ message: String) {
        guard isE2EEnabled else { return }
        let line = "\(Date()) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: Self.e2eEventsPath)) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: URL(fileURLWithPath: Self.e2eEventsPath))
        }
    }

    private static let e2eFramesPath = "/tmp/roster-e2e-frames.tsv"
    private static let e2eEventsPath = "/tmp/roster-e2e-events.log"

    private func prunedAssignments(_ assignments: [String: Set<String>]) -> [String: Set<String>] {
        Self.prunedAssignments(assignments, keeping: Set(contactTags.map(\.id)))
    }

    private static func prunedAssignments(
        _ assignments: [String: Set<String>],
        keeping tagIDs: Set<String>
    ) -> [String: Set<String>] {
        return assignments.compactMapValues { ids in
            let pruned = ids.intersection(tagIDs)
            return pruned.isEmpty ? nil : pruned
        }
    }

    private func pruneEmptyContactTagsIfNeeded() async {
        let emptyTagIDs = contactTagTree
            .emptySubtreeTagIDs(assignmentsByContactID: contactTagAssignmentsByContactID)
        guard !emptyTagIDs.isEmpty else { return }

        await contactTagStore.deleteTags(tagIDs: emptyTagIDs)
        contactTags.removeAll { emptyTagIDs.contains($0.id) }
        expandedTagIDs.subtract(emptyTagIDs)
        contactTagAssignmentsByContactID = Self.prunedAssignments(
            contactTagAssignmentsByContactID,
            keeping: Set(contactTags.map(\.id))
        )
        rebuildContactTagFilterOptions()
        if case let .tag(selectedID) = selectedTagsFilter, emptyTagIDs.contains(selectedID) {
            selectedTagsFilter = .all
        }
        if case let .tag(selectedID) = rosterTagFilter, emptyTagIDs.contains(selectedID) {
            rosterTagFilter = .all
        }
    }

    private static func tagFilterOptions(
        tags: [ContactTag],
        tree: ContactTagTree,
        assignmentsByContactID: [String: Set<String>],
        visibleContactIDs: Set<String>,
        allText: String,
        untaggedText: String
    ) -> [ContactTagSelectionOption] {
        let sortedTags = tags.sorted(by: compareTags(_:_:))
        let untaggedCount = visibleContactIDs.filter { (assignmentsByContactID[$0] ?? []).isEmpty }.count
        var options = [
            ContactTagSelectionOption(id: "all", title: allText, filter: .all, count: visibleContactIDs.count, tag: nil),
            ContactTagSelectionOption(id: "untagged", title: untaggedText, filter: .untagged, count: untaggedCount, tag: nil)
        ]

        options += sortedTags.map { tag in
            let matchingTagIDs = tree.tagAndDescendantIDs(for: tag.id)
            let count = visibleContactIDs.filter { contactID in
                !(assignmentsByContactID[contactID] ?? []).intersection(matchingTagIDs).isEmpty
            }.count
            return ContactTagSelectionOption(id: tag.id, title: tree.displayPath(for: tag.id), filter: .tag(tag.id), count: count, tag: tag)
        }
        return options
    }

    private static func compareTags(_ lhs: ContactTag, _ rhs: ContactTag) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func bulkTagToast(count: Int) -> String {
        switch language.coreLocale {
        case .english: "Added tags to \(count) contacts"
        case .simplifiedChinese: "已为 \(count) 位联系人添加标签"
        case .traditionalChinese: "已為 \(count) 位聯絡人新增標籤"
        }
    }

    private func groupAssignmentToast(groupName: String, count: Int) -> String {
        switch language.coreLocale {
        case .english: "Moved \(count) contacts to \(groupName)"
        case .simplifiedChinese: "已将 \(count) 位联系人移动到\(groupName)"
        case .traditionalChinese: "已將 \(count) 位聯絡人移至\(groupName)"
        }
    }

    private func contactGroupCreateSummary(groupName: String) -> String {
        switch language.coreLocale {
        case .english: "Create contact group \(groupName)"
        case .simplifiedChinese: "新建通讯录分组\(groupName)"
        case .traditionalChinese: "新增通訊錄分組\(groupName)"
        }
    }

    private func contactGroupDeleteSummary(groupName: String) -> String {
        switch language.coreLocale {
        case .english: "Delete contact group \(groupName)"
        case .simplifiedChinese: "删除通讯录分组\(groupName)"
        case .traditionalChinese: "刪除通訊錄分組\(groupName)"
        }
    }

    private var groupOperationKinds: Set<ContactOperationKind> {
        [.createGroup, .deleteGroup]
    }

    private func contactQueuedText(count: Int) -> String {
        switch language.coreLocale {
        case .english: "Queued \(count) contact change\(count == 1 ? "" : "s")"
        case .simplifiedChinese: "已加入 \(count) 条待写入操作"
        case .traditionalChinese: "已加入 \(count) 筆待寫入操作"
        }
    }

    private var contactConflictText: String {
        switch language.coreLocale {
        case .english: "A contact changed in macOS Contacts. Resolve the conflict before writing."
        case .simplifiedChinese: "macOS 通讯录中有联系人发生外部变更，请先处理冲突。"
        case .traditionalChinese: "macOS 通訊錄中有聯絡人發生外部變更，請先處理衝突。"
        }
    }

    private var contactCreateUnsupportedText: String {
        switch language.coreLocale {
        case .english: "Bearoster can’t create new contacts in macOS Contacts yet. Add them in Contacts and they’ll show up here."
        case .simplifiedChinese: "还不能在 macOS 通讯录里新建联系人，可以先在通讯录里添加，这里会同步显示。"
        case .traditionalChinese: "還不能在 macOS 通訊錄裡新建聯絡人，可以先在通訊錄裡新增，這裡會同步顯示。"
        }
    }

    private var contactRestoredText: String {
        switch language.coreLocale {
        case .english: "Contact restored locally"
        case .simplifiedChinese: "已从回收站恢复到本地"
        case .traditionalChinese: "已從垃圾桶恢復到本機"
        }
    }

    private func contactUpdateSummary(for draft: LocalContactDraft) -> String {
        switch language.coreLocale {
        case .english: "Updated contact fields for \(draft.displayName)"
        case .simplifiedChinese: "更新 \(draft.displayName) 的联系人字段"
        case .traditionalChinese: "更新 \(draft.displayName) 的聯絡人欄位"
        }
    }

    private func contactDeleteSummary(for draft: LocalContactDraft) -> String {
        switch language.coreLocale {
        case .english: "Moved \(draft.displayName) to Trash"
        case .simplifiedChinese: "将 \(draft.displayName) 移入回收站"
        case .traditionalChinese: "將 \(draft.displayName) 移入垃圾桶"
        }
    }

    private func contactRestoreSummary(for draft: LocalContactDraft) -> String {
        switch language.coreLocale {
        case .english: "Restored \(draft.displayName)"
        case .simplifiedChinese: "恢复 \(draft.displayName)"
        case .traditionalChinese: "恢復 \(draft.displayName)"
        }
    }

    private func contactFieldChanges(previous: LocalContactDraft, next: LocalContactDraft) -> [ContactFieldChange] {
        var changes: [ContactFieldChange] = []

        appendChange(&changes, field: "name", previous: previous.displayName, next: next.displayName)
        appendChange(&changes, field: "givenName", previous: previous.givenName, next: next.givenName)
        appendChange(&changes, field: "familyName", previous: previous.familyName, next: next.familyName)
        appendChange(&changes, field: "nickname", previous: previous.nickname, next: next.nickname)
        appendChange(&changes, field: "organizationName", previous: previous.organizationName, next: next.organizationName)
        appendChange(&changes, field: "departmentName", previous: previous.departmentName, next: next.departmentName)
        appendChange(&changes, field: "jobTitle", previous: previous.jobTitle, next: next.jobTitle)
        appendChange(&changes, field: "phoneNumbers", previous: previous.phoneNumbers.joined(separator: ", "), next: next.phoneNumbers.joined(separator: ", "))
        appendChange(&changes, field: "emailAddresses", previous: previous.emailAddresses.joined(separator: ", "), next: next.emailAddresses.joined(separator: ", "))
        appendChange(&changes, field: "postalAddresses", previous: previous.postalAddresses.joined(separator: ", "), next: next.postalAddresses.joined(separator: ", "))
        if previous.imageData != next.imageData {
            changes.append(ContactFieldChange(field: "avatar", previousValue: previous.imageData == nil ? "empty" : "set", nextValue: next.imageData == nil ? "empty" : "set"))
        }
        appendChange(
            &changes,
            field: "birthdays",
            previous: previous.birthdaySpecs.map(Self.rosterChangeValue).joined(separator: ", "),
            next: next.birthdaySpecs.map(Self.rosterChangeValue).joined(separator: ", ")
        )

        return changes
    }

    private func appendChange(
        _ changes: inout [ContactFieldChange],
        field: String,
        previous: String,
        next: String
    ) {
        guard previous != next else { return }
        changes.append(ContactFieldChange(field: field, previousValue: previous, nextValue: next))
    }

    private func applyBatchDraft(
        _ draft: ContactBatchEditDraft,
        fillPolicy: ContactBatchFillPolicy,
        to contact: inout LocalContactDraft
    ) {
        applyTextChange(&contact.givenName, next: draft.givenName, fillPolicy: fillPolicy)
        applyTextChange(&contact.familyName, next: draft.familyName, fillPolicy: fillPolicy)
        applyTextChange(&contact.nickname, next: draft.nickname, fillPolicy: fillPolicy)
        applyTextChange(&contact.organizationName, next: draft.organizationName, fillPolicy: fillPolicy)
        applyTextChange(&contact.departmentName, next: draft.departmentName, fillPolicy: fillPolicy)
        applyTextChange(&contact.jobTitle, next: draft.jobTitle, fillPolicy: fillPolicy)

        applyListChange(&contact.phoneNumbers, next: draft.phoneNumbers, fillPolicy: fillPolicy)
        applyListChange(&contact.emailAddresses, next: draft.emailAddresses, fillPolicy: fillPolicy)
        applyListChange(&contact.postalAddresses, next: draft.postalAddresses, fillPolicy: fillPolicy)

        switch draft.renameMode {
        case .replace:
            let needle = draft.renameFind.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty else { break }
            let replacement = draft.renameReplacement
            contact.displayName = contact.displayName.replacingOccurrences(of: needle, with: replacement)
            contact.nickname = contact.nickname.replacingOccurrences(of: needle, with: replacement)
        case .prefix:
            let prefix = draft.renamePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prefix.isEmpty else { break }
            contact.displayName = prefix + contact.displayName
            contact.nickname = prefix + contact.nickname
        case .suffix:
            let suffix = draft.renameSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !suffix.isEmpty else { break }
            contact.displayName += suffix
            contact.nickname += suffix
        }
    }

    private func applyTextChange(
        _ current: inout String,
        next: String,
        fillPolicy: ContactBatchFillPolicy
    ) {
        let trimmed = next.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if fillPolicy == .onlyEmpty, !current.isEmpty {
            return
        }
        current = trimmed
    }

    private func applyListChange(
        _ current: inout [String],
        next rawValue: String,
        fillPolicy: ContactBatchFillPolicy
    ) {
        let values = rawValue
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !values.isEmpty else { return }
        if fillPolicy == .onlyEmpty, !current.isEmpty {
            return
        }
        current = values
    }

    private func moveContacts(_ contactIDs: Set<String>, toGroupID groupID: String) async {
        do {
            let groupName = contactGrouping.groups.first(where: { $0.id == groupID })?.name ?? l10n(.group)
            let plan = ContactAssignmentTargetResolver.groupMovePlan(
                contactIDs: contactIDs,
                targetGroupID: groupID,
                grouping: contactGrouping
            )
            try await contactSyncService.moveContacts(
                contactIDsToAdd: plan.contactIDsToAdd.sorted(),
                toGroupID: groupID,
                contactIDsByGroupIDToRemove: plan.contactIDsByGroupIDToRemove.mapValues { $0.sorted() }
            )
            await refreshContacts()
            toast(groupAssignmentToast(groupName: groupName, count: contactIDs.count))
        } catch {
            errorMessage = L10n(language: language)(.groupAssignmentFailed)
        }
    }

    private func rosterChanges(previous: [RosterDateSpec], next: [RosterDateSpec]) -> [ContactFieldChange] {
        guard previous != next else { return [] }
        return [
            ContactFieldChange(
                field: "birthdays",
                previousValue: previous.map(Self.rosterChangeValue).joined(separator: ", "),
                nextValue: next.map(Self.rosterChangeValue).joined(separator: ", ")
            )
        ]
    }

    private static func rosterChangeValue(_ spec: RosterDateSpec) -> String {
        [
            spec.kind.rawValue,
            spec.year.map(String.init) ?? "----",
            spec.month.map { String(format: "%02d", $0) } ?? "--",
            spec.day.map { String(format: "%02d", $0) } ?? "--"
        ].joined(separator: " ")
    }

    private static let defaultTagColors: [UInt] = [
        0x007AFF,
        0x34C759,
        0xFF9500,
        0x5856D6,
        0xFF3B30,
        0x00A7C7
    ]
}

package struct RosterEditDraft: Equatable {
    package var entries: [RosterEditEntry]
    package var originalDisplayName: String
    package var givenName: String
    package var familyName: String
    package var nickname: String
    package var organizationName: String
    package var departmentName: String
    package var jobTitle: String
    package var phoneNumbersText: String
    package var emailAddressesText: String
    package var postalAddressesText: String
    package var imageData: Data?

    package init(profile: ContactRosterProfile) {
        entries = profile.records.map(RosterEditEntry.init(record:))
        originalDisplayName = profile.displayName
        givenName = profile.givenName
        familyName = profile.familyName
        nickname = profile.nickname
        organizationName = profile.organizationName
        departmentName = profile.departmentName
        jobTitle = profile.jobTitle
        phoneNumbersText = profile.phoneNumbers.joined(separator: "\n")
        emailAddressesText = profile.emailAddresses.joined(separator: "\n")
        postalAddressesText = profile.postalAddresses.joined(separator: "\n")
        imageData = profile.imageData
    }

    package mutating func addEntry(personID: String, kind: RosterCalendarKind = .gregorian) {
        entries.append(RosterEditEntry(personID: personID, kind: kind))
    }

    package mutating func removeEntry(id: String) {
        entries.removeAll { $0.id == id }
    }

    package func payload(personID: String) -> RosterEditPayload? {
        let parsed = entries.map { entry in
            (entry: entry, spec: entry.dateSpec(personID: personID))
        }
        guard parsed.allSatisfy({ $0.spec != nil }) else {
            return nil
        }
        let specs = parsed.compactMap(\.spec)

        let appleGregorian = specs.first {
            $0.source == .appleRoster && $0.kind == .gregorian
        }
        let appleNonGregorian = specs.first {
            $0.source == .appleNonGregorianRoster && $0.kind != .gregorian
        }
        let appleSpecIDs = Set([appleGregorian?.id, appleNonGregorian?.id].compactMap { $0 })
        let localOnlySpecs = specs.filter { !appleSpecIDs.contains($0.id) }

        return RosterEditPayload(
            gregorian: appleGregorian?.components,
            nonGregorianKind: appleNonGregorian?.kind,
            nonGregorian: appleNonGregorian?.components,
            localOnlyDateSpecs: localOnlySpecs
        )
    }

    package func localOnlyDateSpecs(personID: String) -> [RosterDateSpec] {
        payload(personID: personID)?.localOnlyDateSpecs ?? []
    }

    package func profile(personID: String, fallback: ContactRosterProfile) -> ContactRosterProfile? {
        guard let payload = payload(personID: personID) else { return nil }
        let specs = payload.journalRosterSpecs(personID: personID)
        let displayName = Self.displayName(
            givenName: givenName,
            familyName: familyName,
            nickname: nickname,
            organizationName: organizationName,
            fallback: originalDisplayName.isEmpty ? fallback.displayName : originalDisplayName
        )
        let person = RosterPerson(
            id: personID,
            displayName: displayName,
            organizationName: organizationName.trimmingCharacters(in: .whitespacesAndNewlines),
            appleContactIdentifier: fallback.id,
            source: .merged
        )

        return ContactRosterProfile(
            id: personID,
            displayName: displayName,
            organizationName: organizationName.trimmingCharacters(in: .whitespacesAndNewlines),
            records: specs.map { RosterRecord(person: person, dateSpec: $0) },
            givenName: givenName.trimmingCharacters(in: .whitespacesAndNewlines),
            familyName: familyName.trimmingCharacters(in: .whitespacesAndNewlines),
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            departmentName: departmentName.trimmingCharacters(in: .whitespacesAndNewlines),
            jobTitle: jobTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumbers: Self.lines(from: phoneNumbersText),
            emailAddresses: Self.lines(from: emailAddressesText),
            postalAddresses: Self.lines(from: postalAddressesText),
            imageData: imageData
        )
    }

    package var displayNamePreview: String {
        Self.displayName(
            givenName: givenName,
            familyName: familyName,
            nickname: nickname,
            organizationName: organizationName,
            fallback: originalDisplayName
        )
    }

    private static func lines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func displayName(
        givenName: String,
        familyName: String,
        nickname: String,
        organizationName: String,
        fallback: String
    ) -> String {
        let name = [familyName, givenName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined()
        if !name.isEmpty { return name }

        let nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nickname.isEmpty { return nickname }

        let organizationName = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !organizationName.isEmpty { return organizationName }

        return fallback
    }
}

package struct RosterEditEntry: Identifiable, Equatable {
    package var id: String
    package var kind: RosterCalendarKind
    package var year: String
    package var month: String
    package var day: String
    package var isLeapMonth: Bool
    package var source: RosterDateSpecSource

    package init(record: RosterRecord) {
        id = record.id
        kind = record.kind
        year = record.year.map(String.init) ?? ""
        month = record.month.map(String.init) ?? ""
        day = record.day.map(String.init) ?? ""
        isLeapMonth = record.isLeapMonth
        if record.source == .local, !record.id.hasPrefix("local:") {
            source = record.kind == .gregorian ? .appleRoster : .appleNonGregorianRoster
        } else {
            source = record.source
        }
    }

    package init(personID: String, kind: RosterCalendarKind) {
        id = "local:\(personID):\(UUID().uuidString)"
        self.kind = kind
        year = ""
        month = ""
        day = ""
        isLeapMonth = false
        source = .local
    }

    package func dateSpec(personID: String) -> RosterDateSpec? {
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

        return RosterDateSpec(
            id: id,
            personID: personID,
            kind: kind,
            components: value,
            source: source,
            syncPolicy: source == .local ? .localOnly : .writeBackToApple
        )
    }
}

private extension Array where Element == ContactOperationLog {
    mutating func replaceOrInsert(_ operation: ContactOperationLog) {
        if let index = firstIndex(where: { $0.id == operation.id }) {
            self[index] = operation
        } else {
            insert(operation, at: 0)
        }
    }
}

private extension RosterEditPayload {
    func journalRosterSpecs(personID: String) -> [RosterDateSpec] {
        var specs: [RosterDateSpec] = []
        if let gregorian {
            specs.append(RosterDateSpec(
                id: "\(personID)-gregorian",
                personID: personID,
                kind: .gregorian,
                components: gregorian,
                source: .appleRoster,
                syncPolicy: .writeBackToApple
            ))
        }
        if let nonGregorianKind, let nonGregorian {
            specs.append(RosterDateSpec(
                id: "\(personID)-\(nonGregorianKind.rawValue)",
                personID: personID,
                kind: nonGregorianKind,
                components: nonGregorian,
                source: .appleNonGregorianRoster,
                syncPolicy: .writeBackToApple
            ))
        }
        specs.append(contentsOf: localOnlyDateSpecs)
        return specs
    }

    static func journalPayload(from specs: [RosterDateSpec]) -> RosterEditPayload {
        let gregorian = specs.first {
            $0.source == .appleRoster && $0.kind == .gregorian
        }
        let nonGregorian = specs.first {
            $0.source == .appleNonGregorianRoster && $0.kind != .gregorian
        }
        let appleSpecIDs = Set([gregorian?.id, nonGregorian?.id].compactMap { $0 })
        return RosterEditPayload(
            gregorian: gregorian?.components,
            nonGregorianKind: nonGregorian?.kind,
            nonGregorian: nonGregorian?.components,
            localOnlyDateSpecs: specs.filter { !appleSpecIDs.contains($0.id) }
        )
    }
}

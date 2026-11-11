//
//  AppState.swift
//  Water Tally
//
//  Single source of truth for the UI. All data lives on this device in the App Group
//  container (shared with the widget). Apple Health sync is optional and user-controlled.
//

import SwiftUI
import Combine
import WidgetKit
import HealthKit

struct UndoEntry: Identifiable, Equatable {
    let id: UUID
    let ounces: Double
    let date: Date
}

final class AppState: ObservableObject {
    /// Users are asked to acknowledge the legal terms again when this changes.
    static let currentLegalVersion = AppInfo.currentLegalVersion
    static let defaultThemeColor = "#0B4F8A"

    private let defaults = SharedStore.defaults

    // MARK: Published state

    @Published var buttons: [HydrationButton] = []
    @Published var logs: [String: [WaterLog]] = [:]      // key: yyyy-MM-dd
    @Published var selectedDate = Date()
    @Published var isEditMode = false
    @Published var showAddButtonModal = false
    @Published var showCalendar = false
    @Published var showHistory = false
    @Published var showTrends = false
    @Published var isRearrangeMode = false
    @Published var themeColor = AppState.defaultThemeColor
    @Published var dailyGoal = 64.0                       // ounces
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var healthKitEnabled = false
    @Published var hasCompletedOnboarding = false
    @Published var acceptedLegalVersion = 0
    @Published var useMetric = false
    @Published var errorMessage: (title: String, message: String)?
    @Published var undoEntry: UndoEntry?
    @Published var isSyncingHealthKit = false
    @Published var goalJustReached = false

    // Reminders
    @Published var remindersEnabled = false
    @Published var reminderStartHour = 9
    @Published var reminderEndHour = 21
    @Published var reminderIntervalHours = 2

    let healthKitManager = HealthKitManager()
    let maxButtons = Limits.maxButtons

    private var cancellables = Set<AnyCancellable>()
    private var lastActiveDay = Calendar.current.startOfDay(for: Date())

    // MARK: Derived values

    var needsLegalConsent: Bool { acceptedLegalVersion < Self.currentLegalVersion }
    var currentUnitString: String { Volume.unit(metric: useMetric) }
    var maxDisplayAmount: Double { Volume.toDisplay(Limits.maxLogOunces, metric: useMetric) }
    var minDisplayGoal: Double { Volume.toDisplay(Limits.minGoalOunces, metric: useMetric) }
    var maxDisplayGoal: Double { Volume.toDisplay(Limits.maxGoalOunces, metric: useMetric) }

    private var shouldSyncToHealthKit: Bool { healthKitEnabled && healthKitManager.isAuthorized }

    func formatVolume(_ ounces: Double) -> String { Volume.string(ounces, metric: useMetric) }
    func formatNumber(_ ounces: Double) -> String { Volume.number(ounces, metric: useMetric) }
    func convertToDisplayUnit(_ ounces: Double) -> Double { Volume.toDisplay(ounces, metric: useMetric) }
    func convertFromDisplayUnit(_ value: Double) -> Double { Volume.fromDisplay(value, metric: useMetric) }

    // MARK: Init

    init() {
        #if DEBUG
        DebugLaunch.prepareStorage()
        #endif
        loadEverything()
        ReviewPrompter.recordLaunch()
        if buttons.isEmpty && !hasCompletedOnboarding { installDefaultButtons() }
        calculateStreaks()

        healthKitManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.dayDidChange() }
            .store(in: &cancellables)
    }

    private func installDefaultButtons(metric: Bool = false) {
        let amounts: [Double] = metric
            ? [250, 500, 750].map { Volume.fromDisplay($0, metric: true) }
            : [8, 16, 24]
        buttons = [
            HydrationButton(name: "Glass", fluidOunces: amounts[0], order: 0, color: "#00A8CC"),
            HydrationButton(name: "Bottle", fluidOunces: amounts[1], order: 1, color: "#0077B6"),
            HydrationButton(name: "Large Bottle", fluidOunces: amounts[2], order: 2, color: "#1565C0")
        ]
        saveButtons()
    }

    /// Onboarding: if the user picked metric and hasn't customised anything yet, swap the
    /// default ounce-based buttons for round millilitre amounts.
    func useMetricDefaultButtonsIfUntouched() {
        let names = buttons.map(\.name)
        let amounts = buttons.map(\.fluidOunces)
        if names == ["Glass", "Bottle", "Large Bottle"] && amounts == [8, 16, 24] {
            installDefaultButtons(metric: true)
        }
    }

    // MARK: Loading

    private func loadEverything() {
        reloadFromDisk()
        hasCompletedOnboarding = defaults.bool(forKey: SharedStore.Key.onboarded)
        acceptedLegalVersion = defaults.integer(forKey: SharedStore.Key.legalVersion)
        healthKitEnabled = defaults.bool(forKey: "healthKitEnabled")
        remindersEnabled = defaults.bool(forKey: "remindersEnabled")
        if defaults.object(forKey: "reminderStartHour") != nil {
            reminderStartHour = defaults.integer(forKey: "reminderStartHour")
            reminderEndHour = defaults.integer(forKey: "reminderEndHour")
            reminderIntervalHours = max(1, defaults.integer(forKey: "reminderIntervalHours"))
        }
    }

    /// Re-reads everything the widget can change. Called when the app returns to the foreground
    /// so a widget log is never overwritten by stale in-memory state.
    func reloadFromDisk() {
        if let stored = SharedStore.loadLogs() { logs = stored }
        if let storedButtons = SharedStore.loadButtons() { buttons = storedButtons }
        dailyGoal = SharedStore.storedGoal()
        useMetric = defaults.bool(forKey: SharedStore.Key.useMetric)
        if let color = defaults.string(forKey: SharedStore.Key.themeColor) { themeColor = color }
        longestStreak = defaults.integer(forKey: SharedStore.Key.longestStreak)
    }

    // MARK: Lifecycle

    func handleBecameActive() {
        reloadFromDisk()
        healthKitManager.refreshAuthorization()
        if !Calendar.current.isDate(lastActiveDay, inSameDayAs: Date()) { dayDidChange() }
        calculateStreaks()
        syncPendingLogsToHealthKit()
        rescheduleReminders()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func dayDidChange() {
        let calendar = Calendar.current
        // If the user was looking at "today" when midnight passed, follow the clock.
        if calendar.isDate(selectedDate, inSameDayAs: lastActiveDay) {
            selectedDate = Date()
        }
        lastActiveDay = calendar.startOfDay(for: Date())
        calculateStreaks()
        rescheduleReminders()
    }

    // MARK: Onboarding & legal

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: SharedStore.Key.onboarded)
    }

    func acceptLegal() {
        acceptedLegalVersion = Self.currentLegalVersion
        defaults.set(acceptedLegalVersion, forKey: SharedStore.Key.legalVersion)
        defaults.set(Date().timeIntervalSince1970, forKey: "acceptedLegalDate")
    }

    // MARK: Preferences

    func saveUnitPreference() {
        defaults.set(useMetric, forKey: SharedStore.Key.useMetric)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func saveHealthKitPreference() {
        defaults.set(healthKitEnabled, forKey: "healthKitEnabled")
    }

    func setThemeColor(_ hex: String) {
        themeColor = hex
        defaults.set(hex, forKey: SharedStore.Key.themeColor)
    }

    func saveGoal() {
        dailyGoal = min(max(dailyGoal, Limits.minGoalOunces), Limits.maxGoalOunces)
        defaults.set(dailyGoal, forKey: SharedStore.Key.goal)
        calculateStreaks()
        rescheduleReminders()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func saveReminderPreferences() {
        defaults.set(remindersEnabled, forKey: "remindersEnabled")
        defaults.set(reminderStartHour, forKey: "reminderStartHour")
        defaults.set(reminderEndHour, forKey: "reminderEndHour")
        defaults.set(reminderIntervalHours, forKey: "reminderIntervalHours")
        rescheduleReminders()
    }

    func setReminders(enabled: Bool) {
        guard enabled else {
            remindersEnabled = false
            saveReminderPreferences()
            return
        }
        ReminderScheduler.requestAuthorization { [weak self] granted in
            guard let self else { return }
            self.remindersEnabled = granted
            self.saveReminderPreferences()
            if !granted {
                self.errorMessage = (
                    title: "Notifications Are Off",
                    message: "To get reminders, allow notifications for \(AppInfo.name) in the Settings app."
                )
            }
        }
    }

    func rescheduleReminders() {
        ReminderScheduler.reschedule(
            enabled: remindersEnabled,
            startHour: reminderStartHour,
            endHour: reminderEndHour,
            intervalHours: reminderIntervalHours,
            goalMetToday: Limits.isGoalMet(total: totalFluidOunces(for: Date()), goal: dailyGoal)
        )
    }

    // MARK: Date helpers

    func dateKey(for date: Date) -> String { DayKey.string(for: date) }
    func isToday(_ date: Date) -> Bool { Calendar.current.isDateInToday(date) }

    /// Moves the viewed day; never past today.
    func shiftSelectedDate(by days: Int) {
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .day, value: days, to: selectedDate),
              calendar.startOfDay(for: target) <= calendar.startOfDay(for: Date()) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedDate = target }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func dateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// Timestamp used when logging while viewing `selectedDate`: "now" for today, otherwise
    /// the viewed day at the current time of day.
    func timestampForLogging() -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) { return Date() }
        let time = calendar.dateComponents([.hour, .minute, .second], from: Date())
        return calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0,
                             second: time.second ?? 0, of: selectedDate) ?? selectedDate
    }

    // MARK: Goal celebration (shown at most once per day)

    func shouldCelebrateGoal(on date: Date) -> Bool {
        !defaults.bool(forKey: "goalCelebrated_\(dateKey(for: date))")
    }

    func markGoalCelebrated(on date: Date) {
        defaults.set(true, forKey: "goalCelebrated_\(dateKey(for: date))")
    }

    // MARK: Totals

    func totalFluidOunces(for date: Date) -> Double {
        logs[dateKey(for: date)]?.reduce(0) { $0 + $1.fluidOunces } ?? 0
    }

    func goalProgress(for date: Date) -> Double {
        guard dailyGoal > 0 else { return 0 }
        return min(totalFluidOunces(for: date) / dailyGoal, 1)
    }

    func logsForDate(_ date: Date) -> [WaterLog] {
        logs[dateKey(for: date)]?.sorted { $0.timestamp > $1.timestamp } ?? []
    }

    func daysWithLogs() -> Set<String> {
        Set(logs.compactMap { $0.value.isEmpty ? nil : $0.key })
    }

    func hasHistoricalLogs() -> Bool {
        let todayKey = dateKey(for: Date())
        return logs.contains { !$0.value.isEmpty && $0.key < todayKey }
    }

    func calculateStreaks() {
        let result = StreakCalculator.compute(logs: logs, goal: dailyGoal)
        let best = max(result.longest, defaults.integer(forKey: SharedStore.Key.longestStreak))
        currentStreak = result.current
        longestStreak = best
        defaults.set(result.current, forKey: SharedStore.Key.currentStreak)
        defaults.set(best, forKey: SharedStore.Key.longestStreak)
    }

    // MARK: Logging

    private func persistLogs() {
        SharedStore.saveLogs(logs)
        calculateStreaks()
        WidgetCenter.shared.reloadAllTimelines()
        rescheduleReminders()
    }

    @discardableResult
    func addLog(fluidOunces: Double, buttonName: String, date: Date? = nil,
                logId: UUID = UUID(), showUndo: Bool = true) -> UUID? {
        guard fluidOunces >= Limits.minLogOunces && fluidOunces <= Limits.maxLogOunces else {
            errorMessage = (
                title: "Invalid Amount",
                message: "Enter an amount between \(formatVolume(Limits.minLogOunces)) and \(formatVolume(Limits.maxLogOunces))."
            )
            return nil
        }
        let timestamp = date ?? timestampForLogging()
        let key = dateKey(for: timestamp)
        if (logs[key]?.count ?? 0) >= Limits.maxLogsPerDay {
            errorMessage = (
                title: "Daily Limit Reached",
                message: "A day can hold up to \(Limits.maxLogsPerDay) entries. Edit or delete an existing entry instead."
            )
            return nil
        }

        let wasMet = Limits.isGoalMet(total: totalFluidOunces(for: timestamp), goal: dailyGoal)
        let log = WaterLog(id: logId, fluidOunces: fluidOunces, timestamp: timestamp, buttonName: buttonName)
        logs[key, default: []].append(log)
        if !wasMet, Calendar.current.isDateInToday(timestamp),
           Limits.isGoalMet(total: totalFluidOunces(for: timestamp), goal: dailyGoal),
           shouldCelebrateGoal(on: timestamp) {
            markGoalCelebrated(on: timestamp)
            goalJustReached = true
        }
        recordUsage(ofButtonNamed: buttonName)
        persistLogs()

        if showUndo { undoEntry = UndoEntry(id: log.id, ounces: fluidOunces, date: timestamp) }

        if shouldSyncToHealthKit {
            healthKitManager.save([log]) { [weak self] saved in
                if saved.contains(log.id) { self?.markSynced(ids: saved) }
            }
        }
        return log.id
    }

    func deleteLog(id: UUID, date: Date) {
        let key = dateKey(for: date)
        guard let log = logs[key]?.first(where: { $0.id == id }) else { return }
        logs[key]?.removeAll { $0.id == id }
        if logs[key]?.isEmpty == true { logs.removeValue(forKey: key) }
        if undoEntry?.id == id { undoEntry = nil }
        persistLogs()

        if shouldSyncToHealthKit && log.syncedToHealthKit {
            healthKitManager.delete(log: log) { _ in }
        }
    }

    func updateLog(id: UUID, newAmount: Double, date: Date) {
        guard newAmount >= Limits.minLogOunces && newAmount <= Limits.maxLogOunces else { return }
        let key = dateKey(for: date)
        guard let index = logs[key]?.firstIndex(where: { $0.id == id }) else { return }

        let previous = logs[key]![index]
        logs[key]![index].fluidOunces = newAmount
        logs[key]![index].syncedToHealthKit = false
        let updated = logs[key]![index]
        persistLogs()

        if shouldSyncToHealthKit {
            if previous.syncedToHealthKit {
                healthKitManager.replace(log: updated, previous: previous) { [weak self] ok in
                    if ok { self?.markSynced(ids: [id]) }
                }
            } else {
                healthKitManager.save([updated]) { [weak self] saved in self?.markSynced(ids: saved) }
            }
        }
    }

    private func recordUsage(ofButtonNamed name: String) {
        var counts = SharedStore.loadUsageCounts()
        counts[name, default: 0] += 1
        SharedStore.saveUsageCounts(counts)
    }

    // MARK: Apple Health

    private func markSynced(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for (key, dayLogs) in logs where dayLogs.contains(where: { ids.contains($0.id) }) {
            logs[key] = dayLogs.map { log in
                var copy = log
                if ids.contains(log.id) { copy.syncedToHealthKit = true }
                return copy
            }
        }
        SharedStore.saveLogs(logs)
    }

    /// Pushes anything not yet in Health (offline writes, widget logs, entries from before
    /// sync was turned on). Safe to call repeatedly: only unsynced entries are sent.
    func syncPendingLogsToHealthKit(completion: (() -> Void)? = nil) {
        guard shouldSyncToHealthKit, !isSyncingHealthKit else { completion?(); return }
        let pending = logs.values.flatMap { $0 }.filter { !$0.syncedToHealthKit }
        guard !pending.isEmpty else { completion?(); return }

        isSyncingHealthKit = true
        healthKitManager.save(pending) { [weak self] saved in
            guard let self else { return }
            self.markSynced(ids: saved)
            self.isSyncingHealthKit = false
            completion?()
        }
    }

    func setHealthKitEnabled(_ enabled: Bool, completion: ((Bool) -> Void)? = nil) {
        guard enabled else {
            healthKitEnabled = false
            saveHealthKitPreference()
            completion?(false)
            return
        }
        guard healthKitManager.isAvailable else {
            errorMessage = (title: "Health Isn't Available",
                            message: "Apple Health isn't available on this device.")
            completion?(false)
            return
        }

        let finishEnabling = { [weak self] in
            guard let self else { return }
            self.healthKitEnabled = true
            self.saveHealthKitPreference()
            self.syncPendingLogsToHealthKit()
            completion?(true)
        }

        switch healthKitManager.authorizationStatus {
        case .sharingAuthorized:
            finishEnabling()
        case .notDetermined:
            healthKitManager.requestAuthorization { [weak self] granted in
                if granted {
                    finishEnabling()
                } else {
                    self?.healthKitEnabled = false
                    self?.saveHealthKitPreference()
                    self?.errorMessage = (
                        title: "Health Access Not Granted",
                        message: "You can turn on Water access for \(AppInfo.name) any time in Settings > Health > Data Access & Devices."
                    )
                    completion?(false)
                }
            }
        default:
            healthKitEnabled = false
            saveHealthKitPreference()
            errorMessage = (
                title: "Health Access Is Off",
                message: "To sync, allow Water access for \(AppInfo.name) in Settings > Health > Data Access & Devices."
            )
            completion?(false)
        }
    }

    /// Adds water entries found in Apple Health that Water Tally doesn't already have. Never removes
    /// or overwrites anything.
    func restoreFromHealthKit(completion: @escaping (Result<Int, Error>) -> Void) {
        guard shouldSyncToHealthKit else {
            completion(.failure(NSError(domain: AppInfo.name, code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Apple Health sync isn't turned on."
            ])))
            return
        }
        let start = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        healthKitManager.fetchSamples(since: start) { [weak self] samples in
            guard let self else { return }
            let existingIDs = Set(self.logs.values.flatMap { $0 }.map(\.id))
            let allLocal = self.logs.values.flatMap { $0 }
            var added = 0

            for sample in samples {
                guard sample.ounces >= Limits.minLogOunces, sample.ounces <= Limits.maxLogOunces else { continue }
                let id = sample.externalID ?? sample.sampleID
                if existingIDs.contains(id) { continue }

                // Entries written by early builds have no external id: match them by time + amount.
                if sample.writtenByThisApp && sample.externalID == nil {
                    let duplicate = allLocal.contains {
                        abs($0.timestamp.timeIntervalSince(sample.date)) < 2 && abs($0.fluidOunces - sample.ounces) < 0.06
                    }
                    if duplicate { continue }
                }

                let key = self.dateKey(for: sample.date)
                if (self.logs[key]?.count ?? 0) >= Limits.maxLogsPerDay { continue }
                self.logs[key, default: []].append(WaterLog(
                    id: id, fluidOunces: sample.ounces, timestamp: sample.date,
                    buttonName: sample.sourceName, syncedToHealthKit: true
                ))
                added += 1
            }
            if added > 0 { self.persistLogs() }
            completion(.success(added))
        }
    }

    // MARK: Buttons

    func saveButtons() {
        SharedStore.saveButtons(buttons)
        WidgetCenter.shared.reloadAllTimelines()
    }

    @discardableResult
    func addButton(name: String, fluidOunces: Double, color: String = "#00A8CC",
                   showAmount: Bool = true, isCustom: Bool = false) -> Bool {
        guard buttons.count < maxButtons else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || isCustom else { return false }
        guard fluidOunces >= 0 && fluidOunces <= Limits.maxLogOunces else { return false }
        if !isCustom && buttons.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return false
        }
        buttons.append(HydrationButton(name: trimmed, fluidOunces: fluidOunces, order: buttons.count,
                                       color: color, showAmount: showAmount, isCustom: isCustom))
        saveButtons()
        return true
    }

    func updateButton(id: UUID, name: String, fluidOunces: Double, color: String, showAmount: Bool) {
        guard let index = buttons.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, fluidOunces >= 0, fluidOunces <= Limits.maxLogOunces else { return }
        buttons[index].name = trimmed
        buttons[index].fluidOunces = fluidOunces
        buttons[index].color = color
        buttons[index].showAmount = showAmount
        saveButtons()
    }

    func hasCustomButton() -> Bool { buttons.contains { $0.isCustom } }

    func setCustomButton(enabled: Bool) {
        if enabled {
            guard !hasCustomButton(), buttons.count < maxButtons else { return }
            buttons.append(HydrationButton(name: "Custom", fluidOunces: 0, order: buttons.count,
                                           color: "#00A8CC", showAmount: false, isCustom: true))
        } else {
            buttons.removeAll { $0.isCustom }
            reorderButtons()
        }
        saveButtons()
    }

    func deleteButton(id: UUID) {
        buttons.removeAll { $0.id == id }
        reorderButtons()
        saveButtons()
    }

    func moveButton(from source: IndexSet, to destination: Int) {
        buttons.move(fromOffsets: source, toOffset: destination)
        reorderButtons()
        saveButtons()
    }

    func reorderButtons() {
        for index in buttons.indices { buttons[index].order = index }
    }

    // MARK: Deleting data

    /// Wipes everything Water Tally stores on this device and returns the app to its first-run state.
    /// Optionally also removes the water entries Water Tally wrote to Apple Health.
    func deleteAllData(includingHealth: Bool, completion: @escaping () -> Void) {
        let finish = { [weak self] in
            guard let self else { return }
            self.defaults.removePersistentDomain(forName: AppInfo.appGroup)
            self.logs = [:]
            self.buttons = []
            self.installDefaultButtons()
            self.dailyGoal = 64
            self.currentStreak = 0
            self.longestStreak = 0
            self.useMetric = false
            self.themeColor = AppState.defaultThemeColor
            self.healthKitEnabled = false
            self.remindersEnabled = false
            self.hasCompletedOnboarding = false
            self.acceptedLegalVersion = 0
            self.undoEntry = nil
            self.selectedDate = Date()
            self.isEditMode = false
            ReminderScheduler.cancelAll()
            WidgetCenter.shared.reloadAllTimelines()
            completion()
        }

        if includingHealth && healthKitManager.isAuthorized {
            healthKitManager.deleteAllOwnSamples { _ in DispatchQueue.main.async(execute: finish) }
        } else {
            finish()
        }
    }

    // MARK: Export

    func exportDataAsJSON() -> String? {
        let iso = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "app": AppInfo.name,
            "exportDate": iso.string(from: Date()),
            "note": "All amounts are in fluid ounces (oz). 1 oz = 29.5735 ml.",
            "dailyGoalOunces": dailyGoal,
            "logs": logs.keys.sorted().reduce(into: [String: Any]()) { result, key in
                result[key] = (logs[key] ?? []).sorted { $0.timestamp < $1.timestamp }.map { log in
                    ["id": log.id.uuidString,
                     "ounces": log.fluidOunces,
                     "milliliters": (log.fluidOunces * Volume.mlPerOunce * 10).rounded() / 10,
                     "timestamp": iso.string(from: log.timestamp),
                     "entry": log.buttonName] as [String: Any]
                }
            },
            "buttons": buttons.map {
                ["name": $0.name, "ounces": $0.fluidOunces, "color": $0.color, "isCustom": $0.isCustom] as [String: Any]
            }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload,
                                                     options: [.prettyPrinted, .sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func exportDataAsCSV() -> String {
        func field(_ text: String) -> String {
            // Neutralise spreadsheet formula injection and escape quotes.
            var safe = text
            if let first = safe.first, "=+-@\t\r".contains(first) { safe = "'" + safe }
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd,HH:mm:ss"

        var csv = "Date,Time,Amount (oz),Amount (ml),Entry\n"
        for key in logs.keys.sorted() {
            for log in (logs[key] ?? []).sorted(by: { $0.timestamp < $1.timestamp }) {
                let oz = (log.fluidOunces * 100).rounded() / 100
                let ml = (log.fluidOunces * Volume.mlPerOunce).rounded()
                csv += "\(dateFormatter.string(from: log.timestamp)),\(oz),\(Int(ml)),\(field(log.buttonName))\n"
            }
        }
        return csv
    }
}

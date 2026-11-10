//
//  SharedModels.swift
//  Water Tally
//
//  Compiled into BOTH the app and the widget extension so the two can never
//  disagree about the on-disk format (they share data through an App Group).
//

import Foundation

// MARK: - App-wide constants

nonisolated enum AppInfo {
    static let name = "Water Tally"
    static let appGroup = "group.me.ryham.WaterTally"
    static let urlScheme = "watertally"
    static let widgetKind = "WaterTallyWidgets"
    /// Bump when the Terms / Privacy Policy / Medical Disclaimer change materially.
    static let currentLegalVersion = 1
}

// MARK: - Models

nonisolated struct HydrationButton: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var fluidOunces: Double
    var order: Int
    var color: String        // Hex string
    var showAmount: Bool
    var isCustom: Bool       // "Custom input" button (asks for an amount when tapped)

    init(id: UUID = UUID(), name: String, fluidOunces: Double, order: Int,
         color: String = "#00A8CC", showAmount: Bool = true, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.fluidOunces = fluidOunces
        self.order = order
        self.color = color
        self.showAmount = showAmount
        self.isCustom = isCustom
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, fluidOunces, order, color, showAmount, isCustom
    }

    // Tolerant decoding: older builds (and the widget) wrote slightly different shapes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        fluidOunces = try c.decodeIfPresent(Double.self, forKey: .fluidOunces) ?? 0
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#00A8CC"
        showAmount = try c.decodeIfPresent(Bool.self, forKey: .showAmount) ?? true
        isCustom = try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }
}

nonisolated struct WaterLog: Identifiable, Codable, Equatable {
    let id: UUID
    var fluidOunces: Double
    var timestamp: Date
    var buttonName: String
    var syncedToHealthKit: Bool

    init(id: UUID = UUID(), fluidOunces: Double, timestamp: Date = Date(),
         buttonName: String, syncedToHealthKit: Bool = false) {
        self.id = id
        self.fluidOunces = fluidOunces
        self.timestamp = timestamp
        self.buttonName = buttonName
        self.syncedToHealthKit = syncedToHealthKit
    }

    private enum CodingKeys: String, CodingKey {
        case id, fluidOunces, timestamp, buttonName, syncedToHealthKit
    }

    // `syncedToHealthKit` is optional on disk: the widget extension has no HealthKit
    // access, so logs it creates never carry the flag.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        fluidOunces = try c.decode(Double.self, forKey: .fluidOunces)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        buttonName = try c.decodeIfPresent(String.self, forKey: .buttonName) ?? "Water"
        syncedToHealthKit = try c.decodeIfPresent(Bool.self, forKey: .syncedToHealthKit) ?? false
    }
}

// MARK: - Limits

nonisolated enum Limits {
    static let minLogOunces = 0.1
    static let maxLogOunces = 100.0        // ~3 L in a single entry is already extreme
    static let minGoalOunces = 16.0        // ~473 ml
    static let maxGoalOunces = 160.0       // ~4.7 L
    static let highGoalWarningOunces = 135.0 // ~4 L: show a "talk to a professional" note
    static let maxLogsPerDay = 100
    static let maxButtons = 12
    static let goalTolerance = 0.05        // absorbs float error (e.g. 8 x 250 ml vs 2000 ml)

    static func isGoalMet(total: Double, goal: Double) -> Bool {
        goal > 0 && total + goalTolerance >= goal
    }
}

// MARK: - Volume conversion & formatting

nonisolated enum Volume {
    static let mlPerOunce = 29.5735
    static let litersPerOunce = 0.0295735

    static func toDisplay(_ ounces: Double, metric: Bool) -> Double {
        metric ? ounces * mlPerOunce : ounces
    }

    static func fromDisplay(_ value: Double, metric: Bool) -> Double {
        metric ? value / mlPerOunce : value
    }

    static func unit(metric: Bool) -> String { metric ? "ml" : "oz" }

    /// "8", "8.5", "237" — never a trailing ".0". Milliliters are shown as whole numbers.
    static func number(_ ounces: Double, metric: Bool) -> String {
        let value = toDisplay(ounces, metric: metric)
        return number(displayValue: value, metric: metric)
    }

    static func number(displayValue value: Double, metric: Bool) -> String {
        if metric {
            return String(Int(value.rounded()))
        }
        let rounded = (value * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }

    /// "8 oz" / "237 ml"
    static func string(_ ounces: Double, metric: Bool) -> String {
        "\(number(ounces, metric: metric)) \(unit(metric: metric))"
    }
}

// MARK: - Day keys

nonisolated enum DayKey {
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .autoupdatingCurrent
        return c
    }()

    /// Stable "yyyy-MM-dd" key (Gregorian, device time zone) for a local calendar day.
    static func string(for date: Date) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }
}

// MARK: - Streaks

nonisolated enum StreakCalculator {
    /// `current` counts consecutive goal-met days ending today (or yesterday while today is
    /// still in progress). `longest` is the best run inside the look-back window.
    static func compute(logs: [String: [WaterLog]], goal: Double,
                        lookBackDays: Int = 730, now: Date = Date()) -> (current: Int, longest: Int) {
        guard goal > 0 else { return (0, 0) }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        var current = 0
        var longest = 0
        var run = 0
        var currentClosed = false

        for offset in 0..<lookBackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let total = logs[DayKey.string(for: day)]?.reduce(0) { $0 + $1.fluidOunces } ?? 0
            let met = Limits.isGoalMet(total: total, goal: goal)

            if met {
                run += 1
                longest = max(longest, run)
                if !currentClosed { current = run }
            } else {
                run = 0
                // Today being incomplete doesn't end the streak; any earlier miss does.
                if offset > 0 { currentClosed = true }
            }
        }
        return (current, longest)
    }
}

// MARK: - Persistence shared with the widget

nonisolated enum SharedStore {
    enum Key {
        static let logs = "hydrationLogs"
        static let logsBackup = "hydrationLogs.unreadableBackup"
        static let buttons = "hydrationButtons"
        static let usageCounts = "buttonUsageCounts"
        static let goal = "dailyGoal"
        static let useMetric = "useMetric"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let themeColor = "themeColor"
        static let onboarded = "hasCompletedOnboarding"
        static let legalVersion = "acceptedLegalVersion"
    }

    /// Widgets stay inert until the user has finished onboarding and acknowledged the legal terms.
    static var isSetUp: Bool {
        defaults.bool(forKey: Key.onboarded) && defaults.integer(forKey: Key.legalVersion) >= AppInfo.currentLegalVersion
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppInfo.appGroup) ?? .standard
    }

    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    /// Returns `nil` when nothing is stored, `[:]`-or-more when readable. One bad entry
    /// never takes down the rest of the history.
    static func loadLogs() -> [String: [WaterLog]]? {
        guard let data = defaults.data(forKey: Key.logs) else { return nil }
        if let decoded = try? JSONDecoder().decode([String: [WaterLog]].self, from: data) {
            return decoded.filter { !$0.value.isEmpty }
        }
        if let lossy = try? JSONDecoder().decode([String: [Lossy<WaterLog>]].self, from: data) {
            var result: [String: [WaterLog]] = [:]
            for (key, entries) in lossy {
                let good = entries.compactMap(\.value)
                if !good.isEmpty { result[key] = good }
            }
            return result
        }
        // Completely unreadable: keep a copy so nothing is ever silently destroyed.
        if defaults.data(forKey: Key.logsBackup) == nil {
            defaults.set(data, forKey: Key.logsBackup)
        }
        return nil
    }

    static func saveLogs(_ logs: [String: [WaterLog]]) {
        if let data = try? JSONEncoder().encode(logs) {
            defaults.set(data, forKey: Key.logs)
        }
    }

    static func loadButtons() -> [HydrationButton]? {
        guard let data = defaults.data(forKey: Key.buttons),
              let decoded = try? JSONDecoder().decode([HydrationButton].self, from: data) else { return nil }
        return decoded.sorted { $0.order < $1.order }
    }

    static func saveButtons(_ buttons: [HydrationButton]) {
        if let data = try? JSONEncoder().encode(buttons) {
            defaults.set(data, forKey: Key.buttons)
        }
    }

    static func loadUsageCounts() -> [String: Int] {
        guard let data = defaults.data(forKey: Key.usageCounts),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return decoded
    }

    static func saveUsageCounts(_ counts: [String: Int]) {
        if let data = try? JSONEncoder().encode(counts) {
            defaults.set(data, forKey: Key.usageCounts)
        }
    }

    static func storedGoal() -> Double {
        let goal = defaults.double(forKey: Key.goal)
        guard goal > 0 else { return 64 }
        return min(max(goal, Limits.minGoalOunces), Limits.maxGoalOunces)
    }
}

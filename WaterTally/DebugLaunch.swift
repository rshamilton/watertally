//
//  DebugLaunch.swift
//  Water Tally
//
//  DEBUG builds only. Lets you jump straight to a screen with sample data, e.g. for
//  screenshots:
//    xcrun simctl launch booted me.ryham.WaterTally -demoData -showScreen trends
//  Screens: main, edit, settings, trends, history, calendar, goal, weekly, onboarding, consent
//  Flags:   -demoData  -metric  -freshInstall  -simulateLog <oz,oz,...>  -onboardingPage <0-5>
//

#if DEBUG
import SwiftUI

enum DebugLaunch {
    private static let args = ProcessInfo.processInfo.arguments

    static func has(_ flag: String) -> Bool { args.contains(flag) }
    static func value(after flag: String) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    /// Screenshot scripts wait for this file before capturing.
    static func markReady() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("debug-ready")
        try? Data("ready".utf8).write(to: url)
    }

    /// Runs before `AppState` reads storage.
    static func prepareStorage() {
        let defaults = SharedStore.defaults
        if has("-freshInstall") {
            defaults.removePersistentDomain(forName: AppInfo.appGroup)
        }
        guard has("-demoData") else { return }
        defaults.removePersistentDomain(forName: AppInfo.appGroup)
        defaults.set(true, forKey: SharedStore.Key.onboarded)
        defaults.set(AppInfo.currentLegalVersion, forKey: SharedStore.Key.legalVersion)
        defaults.set(has("-metric"), forKey: SharedStore.Key.useMetric)
        defaults.set(64.0, forKey: SharedStore.Key.goal)

        let calendar = Calendar.current
        var logs: [String: [WaterLog]] = [:]
        let sizes: [(String, Double)] = [("Glass", 8), ("Bottle", 16), ("Large Bottle", 24)]
        for offset in 1..<60 {   // today is left empty: use -simulateLog to add today's entries
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            // Deterministic, realistic totals. The last five days meet the 64 oz goal (a visible streak).
            let seed = (offset * 37 + 11) % 100
            let target = offset <= 5 ? 66 + seed % 22 : 34 + (seed * 7) % 52
            var total = 0.0, pick = seed, entry = 0
            var dayLogs: [WaterLog] = []
            while total < Double(target) - 4 && entry < 9 {
                let size = sizes[pick % 3]
                pick += 1
                let hour = min(7 + entry * 2, 21)
                let stamp = calendar.date(bySettingHour: hour, minute: (seed + entry * 13) % 60, second: 0, of: day) ?? day
                dayLogs.append(WaterLog(fluidOunces: size.1, timestamp: stamp, buttonName: size.0))
                total += size.1
                entry += 1
            }
            if !dayLogs.isEmpty { logs[DayKey.string(for: day)] = dayLogs }
        }
        SharedStore.saveLogs(logs)
        SharedStore.saveButtons([
            HydrationButton(name: "Glass", fluidOunces: 8, order: 0, color: "#00A8CC"),
            HydrationButton(name: "Bottle", fluidOunces: 16, order: 1, color: "#0077B6"),
            HydrationButton(name: "Large Bottle", fluidOunces: 24, order: 2, color: "#1565C0"),
            HydrationButton(name: "Custom", fluidOunces: 0, order: 3, color: "#6A1B9A", showAmount: false, isCustom: true)
        ])
    }
}

extension AppState {
    /// Opens the screen requested by `-showScreen`.
    func applyDebugLaunchArguments() {
        // -simulateLog 8,16,16  adds entries spread over the last few hours (oldest first).
        if let list = DebugLaunch.value(after: "-simulateLog") {
            let amounts = list.split(separator: ",").compactMap { Double($0) }
            for (index, amount) in amounts.enumerated() {
                let minutesAgo = Double(amounts.count - 1 - index) * 40
                let name = amount == 8 ? "Glass" : amount == 16 ? "Bottle" : amount == 24 ? "Large Bottle" : "Custom"
                addLog(fluidOunces: amount, buttonName: name,
                       date: Date().addingTimeInterval(-minutesAgo * 60), showUndo: false)
            }
        }
        guard let screen = DebugLaunch.value(after: "-showScreen") else {
            NSLog("DEBUGLAUNCH applied")
            return
        }
        NSLog("DEBUGLAUNCH applying screen=%@", screen)
        switch screen {
        case "edit": isEditMode = true
        case "trends": showTrends = true
        case "history": showHistory = true
        case "calendar": showCalendar = true
        case "goal": isEditMode = true
        case "yesterday": selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        case "consent": acceptedLegalVersion = 0
        case "onboarding": hasCompletedOnboarding = false
        default: break
        }
    }
}
#endif

//
//  ReviewPrompter.swift
//  Water Tally
//
//  Decides when it's reasonable to show Apple's "Rate this app" prompt. We only ask
//  after someone has clearly been using the app for a while, only right after a good
//  moment (reaching the daily goal), at most once per app version and never more than
//  every 120 days. iOS applies its own limit on top (at most three times a year) and
//  may choose not to show the prompt at all.
//

import Foundation

enum ReviewPrompter {
    static let minimumDaysSinceFirstLaunch = 7
    static let minimumDaysLogged = 5
    static let minimumEntries = 20
    static let minimumDaysBetweenPrompts = 120

    private enum Key {
        static let firstLaunch = "review.firstLaunchDate"
        static let lastPrompt = "review.lastPromptDate"
        static let lastPromptVersion = "review.lastPromptVersion"
    }

    private static var defaults: UserDefaults { SharedStore.defaults }

    /// Call once per launch so the "used for a week" rule has a starting point.
    static func recordLaunch(now: Date = Date()) {
        if defaults.object(forKey: Key.firstLaunch) == nil {
            defaults.set(now.timeIntervalSince1970, forKey: Key.firstLaunch)
        }
    }

    static func shouldAsk(logs: [String: [WaterLog]], version: String, now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        guard let first = defaults.object(forKey: Key.firstLaunch) as? Double else { return false }
        let firstDate = Date(timeIntervalSince1970: first)
        guard let days = calendar.dateComponents([.day], from: firstDate, to: now).day,
              days >= minimumDaysSinceFirstLaunch else { return false }

        let daysLogged = logs.values.filter { !$0.isEmpty }.count
        let entries = logs.values.reduce(0) { $0 + $1.count }
        guard daysLogged >= minimumDaysLogged, entries >= minimumEntries else { return false }

        if defaults.string(forKey: Key.lastPromptVersion) == version { return false }
        if let last = defaults.object(forKey: Key.lastPrompt) as? Double,
           let since = calendar.dateComponents([.day], from: Date(timeIntervalSince1970: last), to: now).day,
           since < minimumDaysBetweenPrompts {
            return false
        }
        return true
    }

    static func recordPrompt(version: String, now: Date = Date()) {
        defaults.set(now.timeIntervalSince1970, forKey: Key.lastPrompt)
        defaults.set(version, forKey: Key.lastPromptVersion)
    }
}

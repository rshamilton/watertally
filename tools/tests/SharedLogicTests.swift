// Standalone tests for Shared/SharedModels.swift. Run: tools/run-tests.sh
import Foundation

var failures = 0
func check(_ cond: Bool, _ msg: String, line: Int = #line) {
    if !cond { failures += 1; print("FAIL line \(line): \(msg)") }
}

// --- Volume formatting
check(Volume.string(8, metric: false) == "8 oz", "8 oz")
check(Volume.string(8.25, metric: false) == "8.3 oz" || Volume.string(8.25, metric: false) == "8.2 oz", "8.25 oz -> \(Volume.string(8.25, metric: false))")
check(Volume.string(8, metric: true) == "237 ml", "8oz in ml -> \(Volume.string(8, metric: true))")
check(Volume.number(Volume.fromDisplay(250, metric: true), metric: true) == "250", "250ml roundtrip")
check(Volume.number(displayValue: 64.0, metric: false) == "64", "64")

// --- Goal tolerance: 8 x 250 ml must meet 2000 ml
let goal = Volume.fromDisplay(2000, metric: true)
let total = (0..<8).reduce(0.0) { acc, _ in acc + Volume.fromDisplay(250, metric: true) }
check(Limits.isGoalMet(total: total, goal: goal), "8x250ml meets 2000ml goal")
check(!Limits.isGoalMet(total: 63, goal: 64), "63 < 64")

// --- Widget-written log (no syncedToHealthKit key) must decode
let widgetJSON = """
{"2026-09-21":[{"id":"6C2B1F0E-8E9A-4B54-9D4C-0F0E1A2B3C4D","fluidOunces":8,"timestamp":790000000,"buttonName":"Widget"}]}
""".data(using: .utf8)!
let decoded = try? JSONDecoder().decode([String: [WaterLog]].self, from: widgetJSON)
check(decoded?["2026-09-21"]?.first?.syncedToHealthKit == false, "widget log decodes without syncedToHealthKit")

// Legacy app-written log with all keys
let legacyJSON = """
{"2026-09-20":[{"id":"6C2B1F0E-8E9A-4B54-9D4C-0F0E1A2B3C4E","fluidOunces":16,"timestamp":790000000,"buttonName":"Bottle","syncedToHealthKit":true}]}
""".data(using: .utf8)!
check((try? JSONDecoder().decode([String: [WaterLog]].self, from: legacyJSON))?["2026-09-20"]?.first?.syncedToHealthKit == true, "legacy decodes")

// Legacy button (with old `size` key, missing keys) decodes
let buttonJSON = """
[{"id":"6C2B1F0E-8E9A-4B54-9D4C-0F0E1A2B3C4F","name":"Glass","fluidOunces":8,"order":0,"color":"#00A8CC","showAmount":true,"isCustom":false,"size":"half"}]
""".data(using: .utf8)!
check((try? JSONDecoder().decode([HydrationButton].self, from: buttonJSON))?.count == 1, "legacy button decodes")

// --- Lossy loading: one corrupt log doesn't drop the rest
let d = UserDefaults(suiteName: AppInfo.appGroup)!
d.removePersistentDomain(forName: AppInfo.appGroup)
let mixed = """
{"2026-09-20":[{"id":"6C2B1F0E-8E9A-4B54-9D4C-0F0E1A2B3C4E","fluidOunces":16,"timestamp":790000000,"buttonName":"Bottle"},{"broken":true}]}
""".data(using: .utf8)!
d.set(mixed, forKey: SharedStore.Key.logs)
check(SharedStore.loadLogs()?["2026-09-20"]?.count == 1, "lossy load keeps good entry")
d.set(Data("not json".utf8), forKey: SharedStore.Key.logs)
check(SharedStore.loadLogs() == nil, "unreadable -> nil")
check(d.data(forKey: SharedStore.Key.logsBackup) != nil, "unreadable data was backed up")
d.removePersistentDomain(forName: AppInfo.appGroup)

// --- Streaks
let cal = Calendar.current
let today = cal.startOfDay(for: Date())
func day(_ off: Int) -> String { DayKey.string(for: cal.date(byAdding: .day, value: -off, to: today)!) }
func log(_ oz: Double) -> [WaterLog] { [WaterLog(fluidOunces: oz, buttonName: "t")] }

var logs: [String: [WaterLog]] = [:]
// today incomplete (30), yesterday..3 days ago met, 4 days ago missed, 5..7 met
logs[day(0)] = log(30)
for o in 1...3 { logs[day(o)] = log(64) }
for o in 5...7 { logs[day(o)] = log(64) }
var r = StreakCalculator.compute(logs: logs, goal: 64)
check(r.current == 3, "current streak ignores incomplete today: got \(r.current)")
check(r.longest == 3, "longest = 3: got \(r.longest)")

logs[day(0)] = log(64)   // today complete
r = StreakCalculator.compute(logs: logs, goal: 64)
check(r.current == 4, "today complete extends streak: got \(r.current)")

logs[day(1)] = nil       // yesterday missed
r = StreakCalculator.compute(logs: logs, goal: 64)
check(r.current == 1, "yesterday missed: streak 1, got \(r.current)")

r = StreakCalculator.compute(logs: [:], goal: 64)
check(r.current == 0 && r.longest == 0, "empty")

// Longest run further back than current
var back: [String: [WaterLog]] = [:]
for o in 10...16 { back[day(o)] = log(64) }
r = StreakCalculator.compute(logs: back, goal: 64)
check(r.current == 0 && r.longest == 7, "longest 7 in the past: \(r)")

// --- Day key
check(DayKey.string(for: today).count == 10, "day key format")

print(failures == 0 ? "ALL TESTS PASSED" : "\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)

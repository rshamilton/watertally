//
//  ReminderScheduler.swift
//  Water Tally
//
//  Optional, fully local drink reminders. Nothing is sent to a server. Reminders are laid out
//  a couple of days ahead and re-laid every time the app opens or a log changes, so once
//  today's goal is met the rest of today's reminders disappear.
//

import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let prefix = "watertally.reminder."
    private static let daysAhead = 3

    private static let messages = [
        "Time for a glass of water.",
        "A quick sip? Your log is one tap away.",
        "Water break!",
        "Log your next drink.",
        "Stay on track today."
    ]

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    static func reschedule(enabled: Bool, startHour: Int, endHour: Int, intervalHours: Int, goalMetToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let old = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            guard enabled, endHour >= startHour, intervalHours > 0 else { return }

            let calendar = Calendar.current
            let now = Date()
            var messageIndex = 0

            for dayOffset in 0..<daysAhead {
                if dayOffset == 0 && goalMetToday { continue }
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

                for hour in stride(from: startHour, through: endHour, by: intervalHours) {
                    guard let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                          fire > now.addingTimeInterval(60) else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = AppInfo.name
                    content.body = messages[messageIndex % messages.count]
                    content.sound = .default
                    messageIndex += 1

                    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                    let id = "\(prefix)\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)-\(hour)"
                    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }
    }
}

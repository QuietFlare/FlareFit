//
//  ReminderScheduler.swift
//  FlareFit
//
//  Schedules weekly local notifications for plan reminders.
//  Everything is on-device — no server, no push infrastructure.
//

import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let idPrefix = "flarefit-plan-"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Rebuilds all pending plan notifications from the current plans.
    /// Called whenever plans change — cheap, and always consistent.
    static func sync(plans: [WorkoutPlan]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)

            for plan in plans {
                guard let reminder = plan.reminder, reminder.enabled, !reminder.weekdays.isEmpty else {
                    continue
                }
                for weekday in reminder.weekdays {
                    // Shift the fire time back by the lead, handling midnight rollover.
                    var totalMinutes = reminder.hour * 60 + reminder.minute - reminder.leadMinutes
                    var fireDay = weekday
                    if totalMinutes < 0 {
                        totalMinutes += 24 * 60
                        fireDay = weekday == 1 ? 7 : weekday - 1
                    }

                    var components = DateComponents()
                    components.weekday = fireDay
                    components.hour = totalMinutes / 60
                    components.minute = totalMinutes % 60

                    let content = UNMutableNotificationContent()
                    content.title = "FlareFit"
                    content.body = reminder.leadMinutes == 0
                        ? "Time for \(plan.name). Let's go! 🔥"
                        : "\(plan.name) starts in \(reminder.leadMinutes) minutes. 🔥"
                    content.sound = .default

                    let request = UNNotificationRequest(
                        identifier: "\(idPrefix)\(plan.id.uuidString)-\(fireDay)",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    )
                    center.add(request)
                }
            }
        }
    }
}

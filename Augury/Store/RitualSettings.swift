import Foundation
import UserNotifications

/// A full reader's intentional choice for future deals. This is a preference,
/// not an entitlement: free readers always receive the Major Arcana deck.
enum ReadingDeckPreference: String, CaseIterable {
    case fullDeck
    case majorArcana

    var title: String {
        switch self {
        case .fullDeck: "Full 78-card deck"
        case .majorArcana: "Major Arcana only"
        }
    }

    func deck(for entitlement: Entitlement) -> [Arcana] {
        guard entitlement.isFull else { return entitlement.deck }
        switch self {
        case .fullDeck: return entitlement.deck
        case .majorArcana: return entitlement.deck.filter(\.isMajor)
        }
    }
}

enum RitualReminderFrequency: String, CaseIterable {
    case daily
    case weekly

    var title: String { self == .daily ? "Daily" : "Weekly" }
}

enum RitualReminderAuthorization {
    case notDetermined
    case granted
    case denied
}

/// Local-only ritual notifications. They never draw a card, inspect the
/// journal, or include personal data; the system delivers the same quiet
/// invitation at the reader's chosen time.
enum RitualReminderScheduler {
    static let identifier = "augury.ritual-reminder"

    static func authorization() async -> RitualReminderAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            .granted
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        @unknown default:
            .denied
        }
    }

    /// Requests access only after the reader explicitly enables reminders.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(frequency: RitualReminderFrequency,
                         minutesAfterMidnight: Int,
                         weekday: Int) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Augury"
        content.body = "Time for your Augury ritual."
        content.sound = .default

        let safeMinutes = min(max(minutesAfterMidnight, 0), 23 * 60 + 59)
        var components = DateComponents()
        components.hour = safeMinutes / 60
        components.minute = safeMinutes % 60
        if frequency == .weekly {
            components.weekday = min(max(weekday, 1), 7)
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

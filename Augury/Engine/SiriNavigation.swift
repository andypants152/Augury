import Foundation

/// A tiny handoff channel between an App Intent and Augury's single SwiftUI
/// scene. The pending value covers a cold launch; the notification makes an
/// already-open app respond immediately.
enum SiriDestination: String {
    case reading
    case journal
}

enum SiriNavigation {
    static let didRequestDestination = Notification.Name("Augury.SiriNavigation.didRequestDestination")
    private static let pendingDestinationKey = "Augury.SiriNavigation.pendingDestination"

    static func request(_ destination: SiriDestination) {
        UserDefaults.standard.set(destination.rawValue, forKey: pendingDestinationKey)
        NotificationCenter.default.post(name: didRequestDestination, object: destination)
    }

    static func consumePendingDestination() -> SiriDestination? {
        defer { UserDefaults.standard.removeObject(forKey: pendingDestinationKey) }
        guard let raw = UserDefaults.standard.string(forKey: pendingDestinationKey) else { return nil }
        return SiriDestination(rawValue: raw)
    }
}

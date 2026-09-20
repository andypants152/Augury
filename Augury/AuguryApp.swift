import SwiftUI

@main
struct AuguryApp: App {
    init() {
        // Register the static Siri / Shortcuts phrases as the app starts.
        AuguryShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

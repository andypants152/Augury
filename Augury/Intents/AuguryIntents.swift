import AppIntents

/// The two common Siri actions: begin the default three-card ritual, or
/// revisit the journal. Both run in the foreground because their value is in
/// Augury's tactile interface rather than a background side effect.
struct StartTarotReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a Tarot Reading"
    static var description = IntentDescription("Open Augury and deal a new three-card tarot reading.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        SiriNavigation.request(.reading)
        return .result(dialog: "Opening a new reading in Augury.")
    }
}

struct OpenJournalIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Tarot Journal"
    static var description = IntentDescription("Open the Augury tarot journal.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        SiriNavigation.request(.journal)
        return .result(dialog: "Opening your Augury journal.")
    }
}

struct AuguryShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .navy

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTarotReadingIntent(),
            phrases: [
                "Start a reading in \(.applicationName)",
                "Deal tarot cards in \(.applicationName)",
                "Read my tarot in \(.applicationName)",
            ],
            shortTitle: "Start reading",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: OpenJournalIntent(),
            phrases: [
                "Open my journal in \(.applicationName)",
                "Show my tarot journal in \(.applicationName)",
            ],
            shortTitle: "Open journal",
            systemImageName: "book"
        )
    }
}

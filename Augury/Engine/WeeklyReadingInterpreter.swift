import Combine
import Foundation
import FoundationModels

/// The calendar-week slice used by the journal's weekly reflection. Keeping
/// this separate from `ReadingStore` preserves the journal's append-only
/// semantics: a weekly reading is an interpretation of entries, never data.
enum WeeklyJournal {
    /// The seven calendar days ending today, inclusive, in chronological order.
    static func entries(from entries: [JournalEntry],
                        endingAt date: Date = Date(),
                        calendar: Calendar = .current) -> [JournalEntry] {
        let end = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -6, to: end) else {
            return []
        }
        return entries
            .filter {
                let day = calendar.startOfDay(for: $0.date)
                return day >= start && day <= end
            }
            .sorted { $0.date < $1.date }
    }
}

/// A private, on-device reflection across the current week's journaled
/// readings and notes. It does not draw cards or persist generated text.
@MainActor
final class WeeklyReadingInterpreter: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case complete(String)
        case unavailable(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    func reset() { state = .idle }

    func interpret(_ entries: [JournalEntry]) {
        guard !entries.isEmpty, state != .loading else { return }
        state = .loading

        Task {
            guard #available(iOS 26.0, *) else {
                state = .unavailable("Weekly readings require iOS 26 or later with Apple Intelligence.")
                return
            }
            do {
                state = .complete(try await Self.generate(entries))
            } catch let error as WeeklyInterpretationError {
                state = .unavailable(error.localizedDescription)
            } catch {
                state = .failed("The weekly reading could not be completed. Please try again.")
            }
        }
    }

    /// Plain, auditable model input: cards and the reader's own notes are the
    /// only weekly context supplied to the model.
    nonisolated static func prompt(for entries: [JournalEntry]) -> String {
        let days = entries.map { entry in
            let cards = zip(Spread.threeCards.positions, entry.reading.draws).map { position, drawn in
                "  - \(position.name): \(drawn.card.name) (\(drawn.orientation.label)). Canonical meaning: \(drawn.meaning)"
            }.joined(separator: "\n")
            let note = entry.note?.isEmpty == false ? entry.note! : "No note recorded."
            return "Day: \(entry.date.formatted(date: .abbreviated, time: .omitted))\n\(cards)\n  - Journal note: \(note)"
        }.joined(separator: "\n\n")

        return """
        Offer a grounded weekly tarot reflection from these saved journal entries.
        Treat tarot as a prompt for personal reflection, not fact, prediction, diagnosis, or instruction.
        Do not claim certainty or supernatural authority. Do not invent events or details beyond the cards and notes. Treat patterns as tentative.
        Do not give medical, legal, financial, or crisis advice. Respect the reader's notes as their private words.
        Gently notice themes across the week, then end with one open-ended journaling question.
        Keep the response under 220 words. Do not add a title or markdown.

        \(days)
        """
    }

    @available(iOS 26.0, *)
    private static func generate(_ entries: [JournalEntry]) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw WeeklyInterpretationError.unavailable(availabilityMessage(for: model))
        }
        let session = LanguageModelSession(
            model: model,
            instructions: "You are a thoughtful tarot journal companion. Be warm, concise, non-directive, and grounded."
        )
        return try await session.respond(to: prompt(for: entries)).content
    }

    @available(iOS 26.0, *)
    private static func availabilityMessage(for model: SystemLanguageModel) -> String {
        switch model.availability {
        case .available: return "The on-device model is temporarily unavailable."
        case .unavailable(.deviceNotEligible): return "A compatible Apple Intelligence device is needed for a weekly reading."
        case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence to create a weekly reading."
        case .unavailable(.modelNotReady): return "Apple Intelligence is still preparing its on-device model. Try again shortly."
        @unknown default: return "The on-device model is unavailable right now."
        }
    }

    private enum WeeklyInterpretationError: LocalizedError {
        case unavailable(String)
        var errorDescription: String? {
            switch self { case .unavailable(let message): message }
        }
    }
}

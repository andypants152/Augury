import Foundation
import Combine
import FoundationModels

/// A private, on-device reflection on a completed spread. This is deliberately
/// separate from `ReadingEngine`: a model never chooses cards, orientations, or
/// their canonical meanings. It only helps the reader consider the cards that
/// are already on the table.
@MainActor
final class ReadingInterpreter: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
        case complete(String)
        case unavailable(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    func reset() {
        state = .idle
    }

    /// Start one fresh, stateless Foundation Models session for this spread.
    /// A new session prevents a prior reading from becoming context for the
    /// next one, and keeps the feature entirely on the person's device.
    /// A session that is already running is left alone: the sheet's own
    /// `.task` re-fires if the sheet is reopened mid-flight, and two
    /// generations of one spread would race each other.
    func interpret(_ reading: Reading, in spread: Spread) {
        guard state != .loading else { return }
        state = .loading

        Task {
            guard #available(iOS 26.0, *) else {
                state = .unavailable("AI readings require iOS 26 or later with Apple Intelligence.")
                return
            }
            do {
                let reflection = try await Self.generate(reading, in: spread)
                state = .complete(reflection)
            } catch let error as InterpretationError {
                state = .unavailable(error.localizedDescription)
            } catch {
                state = .failed("The reading could not be completed. Please try again.")
            }
        }
    }

    /// Kept as plain data so the model's input is auditable and unit-testable.
    nonisolated static func prompt(for reading: Reading, in spread: Spread) -> String {
        let cards = zip(spread.positions, reading.draws).map { position, drawn in
            "- \(position.name): \(drawn.card.name) (\(drawn.orientation.label)). Canonical meaning: \(drawn.meaning)"
        }.joined(separator: "\n")

        return """
        Offer a grounded, reflective tarot reading for this completed \(spread.name) spread.
        Treat tarot as a prompt for personal reflection, not fact, prediction, diagnosis, or instruction.
        Do not claim certainty or supernatural authority. Do not give medical, legal, financial, or crisis advice.
        Use the positions and canonical meanings below. Connect the cards into one gentle narrative, then end with one open-ended journaling question.
        Keep the response under 180 words. Do not add a title or markdown.

        \(cards)
        """
    }

    @available(iOS 26.0, *)
    private static func generate(_ reading: Reading, in spread: Spread) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw InterpretationError.unavailable(availabilityMessage(for: model))
        }

        let session = LanguageModelSession(
            model: model,
            instructions: "You are a thoughtful tarot journal companion. Be warm, concise, non-directive, and grounded."
        )
        return try await session.respond(to: prompt(for: reading, in: spread)).content
    }

    @available(iOS 26.0, *)
    private static func availabilityMessage(for model: SystemLanguageModel) -> String {
        switch model.availability {
        case .available:
            return "The on-device model is temporarily unavailable."
        case .unavailable(.deviceNotEligible):
            return "A compatible Apple Intelligence device is needed for an AI reading."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence to create an AI reading."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still preparing its on-device model. Try again shortly."
        @unknown default:
            return "The on-device model is unavailable right now."
        }
    }

    private enum InterpretationError: LocalizedError {
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let message): message
            }
        }
    }
}

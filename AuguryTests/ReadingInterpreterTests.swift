import XCTest
@testable import Augury

final class ReadingInterpreterTests: XCTestCase {
    func testPromptContainsOnlyTheCompletedSpreadContext() {
        let reading = Reading(draws: [
            DrawnCard(card: Arcana.all[0], orientation: .upright),
            DrawnCard(card: Arcana.all[1], orientation: .inverted),
            DrawnCard(card: Arcana.all[2], orientation: .upright),
        ])

        let prompt = ReadingInterpreter.prompt(for: reading, in: .threeCards)

        XCTAssertTrue(prompt.contains("Past: The Fool (upright)"))
        XCTAssertTrue(prompt.contains("Present: The Magician (inverted)"))
        XCTAssertTrue(prompt.contains("Future: The High Priestess (upright)"))
        XCTAssertTrue(prompt.contains("not fact, prediction, diagnosis, or instruction"))
        XCTAssertTrue(prompt.contains("under 180 words"))
    }
}

import XCTest
@testable import Augury

final class WeeklyReadingInterpreterTests: XCTestCase {
    func testWeekIncludesSevenCalendarDaysEndingToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let reading = Reading(draws: [
            DrawnCard(card: Arcana.all[0], orientation: .upright),
            DrawnCard(card: Arcana.all[1], orientation: .inverted),
            DrawnCard(card: Arcana.all[2], orientation: .upright),
        ])
        let included = JournalEntry(date: calendar.date(byAdding: .day, value: -6, to: today)!, reading: reading)
        let excluded = JournalEntry(date: calendar.date(byAdding: .day, value: -7, to: today)!, reading: reading)

        XCTAssertEqual(WeeklyJournal.entries(from: [excluded, included], endingAt: today, calendar: calendar).map(\.id), [included.id])
    }

    func testPromptIncludesCardsNotesAndReflectionBoundaries() {
        let entry = JournalEntry(reading: Reading(draws: [
            DrawnCard(card: Arcana.all[0], orientation: .upright),
            DrawnCard(card: Arcana.all[1], orientation: .inverted),
            DrawnCard(card: Arcana.all[2], orientation: .upright),
        ]), note: "I want to make room for rest.")
        let prompt = WeeklyReadingInterpreter.prompt(for: [entry])

        XCTAssertTrue(prompt.contains("The Fool"))
        XCTAssertTrue(prompt.contains("I want to make room for rest."))
        XCTAssertTrue(prompt.contains("not fact, prediction, diagnosis, or instruction"))
        XCTAssertTrue(prompt.contains("Do not invent events"))
    }
}

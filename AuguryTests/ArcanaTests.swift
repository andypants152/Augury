import XCTest
@testable import Augury

/// M1 — the 78-card `Arcana` content model.
///
/// Done-when (from the roadmap):
///   • the catalog enumerates 78/78,
///   • every field is non-empty,
///   • (bonus) the 22/56 major/minor split and 14-per-suit hold.
final class ArcanaTests: XCTestCase {

    func testCatalogHasExactly78UniqueCards() {
        XCTAssertEqual(Arcana.all.count, 78, "the deck must have exactly 78 cards")
        XCTAssertEqual(Set(Arcana.all.map(\.id)).count, 78, "every ArcanaID appears exactly once")
        XCTAssertEqual(ArcanaID.allCases.count, 78, "the identity enum must have 78 cases")

        // Every identity in the enum has exactly one catalog entry.
        XCTAssertEqual(Set(Arcana.all.map(\.id)), Set(ArcanaID.allCases))
    }

    func testNoFieldIsEmpty() {
        for arcana in Arcana.all {
            XCTAssertFalse(arcana.name.isEmpty, "\(arcana.id) has an empty name")
            XCTAssertFalse(arcana.upright.isEmpty, "\(arcana.id) has an empty upright meaning")
            XCTAssertFalse(arcana.inverted.isEmpty, "\(arcana.id) has an empty inverted meaning")
            XCTAssertFalse(arcana.keywords.isEmpty, "\(arcana.id) has no keywords")
            for keyword in arcana.keywords {
                XCTAssertFalse(
                    keyword.trimmingCharacters(in: .whitespaces).isEmpty,
                    "\(arcana.id) has an empty keyword"
                )
            }
        }
    }

    func testMeaningCountIs156() {
        // 78 cards × (upright + inverted) = 156 meaning strings.
        let meaningStrings = Arcana.all.flatMap { [$0.upright, $0.inverted] }
        XCTAssertEqual(meaningStrings.count, 156)
        XCTAssertTrue(meaningStrings.allSatisfy { !$0.isEmpty })
    }

    func testTwentyTwoMajors() {
        XCTAssertEqual(Arcana.all.filter(\.isMajor).count, 22)
        XCTAssertTrue(Arcana.all.filter(\.isMajor).allSatisfy { $0.suit == nil },
                      "majors carry no suit")
    }

    func testFiftySixMinorsFourteenPerSuit() {
        let minors = Arcana.all.filter { !$0.isMajor }
        XCTAssertEqual(minors.count, 56)
        for suit in Suit.allCases {
            XCTAssertEqual(minors.filter { $0.suit == suit }.count, 14,
                           "suit \(suit.rawValue) should have 14 cards")
        }
    }

    func testKeywordsAreDistinctWithinACard() {
        for arcana in Arcana.all {
            XCTAssertEqual(arcana.keywords.count, Set(arcana.keywords).count,
                           "\(arcana.name) has duplicate keywords")
        }
    }
}

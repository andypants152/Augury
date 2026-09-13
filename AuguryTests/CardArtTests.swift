import XCTest
@testable import Augury

/// The asset-name mapping that ties each card to its line-art layer in
/// `Assets.xcassets`. These names must match the draft file names exactly, or
/// the card renders as a bare background (no figure, frame, or nameplate).
///
/// Regression: majors are named from the *display name*, not the id — six of
/// them (Strength, Wheel of Fortune, Justice, Death, Temperance, Judgement)
/// take no "The", so forcing a `the-` prefix on every major made those six
/// resolve to nonexistent assets and render blank.
final class CardArtTests: XCTestCase {

    private func card(_ id: ArcanaID) -> Arcana {
        guard let c = Arcana.all.first(where: { $0.id == id }) else {
            XCTFail("no card with id \(id)")
            return Arcana.all[0]
        }
        return c
    }

    func testAll78HaveUniqueAssetNames() {
        let names = Arcana.all.map { $0.assetName }
        XCTAssertEqual(names.count, 78)
        XCTAssertEqual(Set(names).count, 78, "asset names must be unique")
    }

    /// The six majors that take no "The" must NOT get the prefix.
    func testMajorsWithoutTheHaveNoPrefix() {
        XCTAssertEqual(card(.strength).assetName, "strength")
        XCTAssertEqual(card(.wheelOfFortune).assetName, "wheel-of-fortune")
        XCTAssertEqual(card(.justice).assetName, "justice")
        XCTAssertEqual(card(.death).assetName, "death")
        XCTAssertEqual(card(.temperance).assetName, "temperance")
        XCTAssertEqual(card(.judgement).assetName, "judgement")
    }

    /// Majors that do take "The" keep it.
    func testMajorsWithTheKeepThePrefix() {
        XCTAssertEqual(card(.fool).assetName, "the-fool")
        XCTAssertEqual(card(.highPriestess).assetName, "the-high-priestess")
        XCTAssertEqual(card(.hangedMan).assetName, "the-hanged-man")
        XCTAssertEqual(card(.emperor).assetName, "the-emperor")
    }

    /// Minors are `suit-rank`, no prefix.
    func testMinorsAreSuitRank() {
        XCTAssertEqual(card(.wandsAce).assetName, "wands-ace")
        XCTAssertEqual(card(.cupsTen).assetName, "cups-ten")
        XCTAssertEqual(card(.swordsPage).assetName, "swords-page")
        XCTAssertEqual(card(.pentaclesKing).assetName, "pentacles-king")
    }

    /// Every asset name is a clean kebab-case identifier (no spaces/uppercase).
    func testAssetNamesAreKebabCase() {
        for card in Arcana.all {
            let n = card.assetName
            let clean = n.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }
            XCTAssertTrue(clean, "\(card.name) → '\(n)' is not kebab-case")
            XCTAssertFalse(n.contains(" "), "\(card.name) → '\(n)' has a space")
        }
    }
}

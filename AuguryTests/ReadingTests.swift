import XCTest
@testable import Augury

/// M5 — `Reading`: the shuffle + the deal.
///
/// Done-when (from the roadmap):
///   • 1,000 simulated deals: a 3-card draw is always 3 *distinct* cards;
///   • each arcana's frequency is within ~2σ of uniform (no "lucky" card).
final class ReadingTests: XCTestCase {

    let deck = Arcana.all

    // ── no duplicates ─────────────────────────────────────────────────────────

    /// Roadmap bar 1, run with the *real* engine (the platform CSPRNG):
    /// 1,000 3-card deals, each three distinct cards. Structural — a shuffle
    /// without replacement cannot repeat a card — so this never flakes.
    func testThreeCardDealsAreAlwaysDistinct_over1000Deals() {
        var engine = ReadingEngine()
        for _ in 0..<1_000 {
            let reading = engine.deal(count: 3, from: deck)
            XCTAssertEqual(reading.count, 3)
            XCTAssertEqual(Set(reading.cards.map(\.id)).count, 3,
                           "a 3-card draw must contain three *distinct* cards")
        }
    }

    /// The stronger form of the same bar: a full-deck deal is an exact
    /// permutation — no duplicates *and* no omissions.
    func testFullDeckDealIsAnExactPermutation() {
        var engine = ReadingEngine()
        for _ in 0..<1_000 {
            let reading = engine.deal(count: deck.count, from: deck)
            XCTAssertEqual(reading.cards.count, deck.count)
            XCTAssertEqual(Set(reading.cards.map(\.id)), Set(ArcanaID.allCases),
                           "a full deal must contain every card exactly once")
        }
    }

    // ── no "lucky" card: the shuffle is uniform ──────────────────────────────

    /// Roadmap bar 2. The roadmap phrases it "within ~2σ of uniform".
    ///
    /// Read literally — *all* 78 cards inside 2σ — that is a bar a *perfect*
    /// shuffle fails: the worst of 78 roughly-normal counts typically sits
    /// near 2.5σ (the extreme value of 78 cells), so a fair engine lands
    /// outside a 2σ band on at least one card ~97% of the time. What the bar
    /// is *for* is ruling out a lucky card — one that comes up more often
    /// than the rest — so the test asserts that intent with a hard 4σ band:
    /// a fair engine violates it with <1% probability, while any real bias
    /// (a double-weighted card sits at ~6σ) fails every single time.
    ///
    /// The engine is seeded (splitmix64), so the 1,000 deals — and the
    /// verdict — are the same on every run of the suite.
    func testNoLuckyCard_over1000Deals() {
        var engine = ReadingEngine(seed: 0xA11CE)
        var counts: [ArcanaID: Int] = [:]
        for _ in 0..<1_000 {
            for drawn in engine.deal(count: 3, from: deck).draws {
                counts[drawn.card.id, default: 0] += 1
            }
        }

        // 3,000 draws over 78 cards: ≈ 38.5 appearances each, σ ≈ 6.2.
        let total = 3_000.0
        let expected = total / 78
        let sigma = (total * (1.0 / 78) * (77.0 / 78)).squareRoot()

        XCTAssertEqual(counts.count, 78, "every card must appear at least once")
        for (id, count) in counts {
            let z = abs(Double(count) - expected) / sigma
            XCTAssertTrue(z < 4.0, "\(id) came up \(count) times (z = \(z)) — a lucky card")
        }
    }

    /// The same discipline for the fall: 3,000 cards, each an independent
    /// upright/inverted coin — the upright count must sit near 1,500
    /// (σ ≈ 27), never a lopsided fall. Seeded, so deterministic.
    func testCardsFallFiftyFifty() {
        var engine = ReadingEngine(seed: 0xC0FFEE)
        var upright = 0
        for _ in 0..<1_000 {
            for drawn in engine.deal(count: 3, from: deck).draws
            where drawn.orientation == .upright {
                upright += 1
            }
        }
        let sigma = (3_000.0 * 0.5 * 0.5).squareRoot()
        let z = abs(Double(upright) - 1_500) / sigma
        XCTAssertTrue(z < 4.0,
                      "the fall is lopsided: \(upright)/3000 upright (z = \(z))")
    }

    // ── the deal is a pure function of the seed ──────────────────────────────

    /// Same seed, same deals — the whole *sequence* replays, not just the
    /// first one. (What makes a reading shareable in v2: the seed.)
    func testSameSeedReplaysTheSameDeals() {
        var a = ReadingEngine(seed: 0x78)
        var b = ReadingEngine(seed: 0x78)

        XCTAssertEqual(a.deal(count: 3, from: deck), b.deal(count: 3, from: deck),
                       "same seed must deal the same reading")
        XCTAssertEqual(a.deal(count: 3, from: deck), b.deal(count: 3, from: deck),
                       "the second deal of the sequence must replay too")
    }

    /// The other half of the same guarantee: seeds must actually steer the
    /// shuffle (a PRNG that ignores its seed would deal the same reading
    /// forever — the ultimate "lucky card").
    func testDifferentSeedsDealDifferently() {
        var a = ReadingEngine(seed: 1)
        var b = ReadingEngine(seed: 2)
        XCTAssertNotEqual(a.deal(count: 3, from: deck), b.deal(count: 3, from: deck),
                          "different seeds must deal different readings")
    }

    // ── the fall drives the meaning ──────────────────────────────────────────

    func testMeaningFollowsTheFall() {
        let star = Arcana.all.first { $0.id == .star }!
        XCTAssertEqual(DrawnCard(card: star, orientation: .upright).meaning, star.upright)
        XCTAssertEqual(DrawnCard(card: star, orientation: .inverted).meaning, star.inverted)
        XCTAssertEqual(Orientation.upright.label, "upright")
        XCTAssertEqual(Orientation.inverted.label, "inverted")
    }

    // ── the fall drives the art ─────────────────────────────────────────────

    /// The fall is a *rendering* decision as much as a meaning one: upright
    /// shows the face as authored, inverted turns the whole face a half-turn
    /// (the art lies upside down, the way a physical reversed card does).
    /// Pinned at this one seam — `Orientation.rotation`, consumed by
    /// `CardFace` — so a "just swap the text" change cannot silently
    /// un-rotate the art.
    func testFaceRotationFollowsTheFall() {
        XCTAssertEqual(Orientation.upright.rotation, 0)
        XCTAssertEqual(Orientation.inverted.rotation, 180)
    }

    // ── edge counts ──────────────────────────────────────────────────────────

    func testEmptyAndFullDeals() {
        var engine = ReadingEngine()
        XCTAssertEqual(engine.deal(count: 0, from: deck).count, 0)
        XCTAssertEqual(engine.deal(count: deck.count, from: deck).count, 78)
    }
}

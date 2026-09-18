import XCTest
@testable import Augury

/// M7 — `Spread` + `SpreadLayout`: the spread catalog and the layout that
/// fits each one.
///
/// Done-when (from the roadmap): the Celtic cross (10 face-down) lays out
/// with no overflow on the smallest iPhone; all spreads deal + reveal
/// correctly. The deal half is structural (`ReadingEngine`, M5 — distinct
/// cards, tested here for every spread's count); the layout half is a pure
/// function, so the overflow bar is pinned exactly.
final class SpreadTests: XCTestCase {

    let deck = Arcana.all

    // ── the catalog ──────────────────────────────────────────────────────────

    func testCatalog() {
        XCTAssertEqual(Spread.all.map(\.id), ["one-card", "three-card", "celtic-cross"])
        XCTAssertEqual(Spread.oneCard.count, 1)
        XCTAssertEqual(Spread.threeCards.count, 3)
        XCTAssertEqual(Spread.celticCross.count, 10)

        for spread in Spread.all {
            XCTAssertFalse(spread.name.isEmpty, "\(spread.id): empty name")
            XCTAssertEqual(Set(spread.positions.map(\.name)).count, spread.count,
                           "\(spread.id): position names must be unique")
            for p in spread.positions {
                XCTAssertFalse(p.name.isEmpty, "\(spread.id): empty position name")
                XCTAssertFalse(p.prompt.isEmpty, "\(spread.id)/\(p.name): empty prompt")
            }
        }
    }

    /// The classic deal order: the cross (present, crossing, foundation,
    /// past, crown) first, then the staff of five — so `draws[i]` lands in
    /// the spot a hand-dealt reading would give it.
    func testCelticCrossCanonicalDealOrder() {
        XCTAssertEqual(Spread.celticCross.positions.map(\.name),
                       ["Present", "Crossing", "Foundation", "Past", "Crown",
                        "Near Future", "Self", "Environment", "Hopes & Fears", "Outcome"])
    }

    // ── the deal: every spread deals distinct cards ─────────────────────────

    /// The structural half of "all spreads deal correctly": a draw without
    /// replacement cannot repeat a card, on the *real* engine (the platform
    /// CSPRNG) — 200 deals per spread, so this never flakes.
    func testEverySpreadDealsDistinctCards() {
        var engine = ReadingEngine()
        for spread in Spread.all {
            for _ in 0..<200 {
                let reading = engine.deal(count: spread.count, from: deck)
                XCTAssertEqual(reading.count, spread.count)
                XCTAssertEqual(Set(reading.cards.map(\.id)).count, spread.count,
                               "\(spread.id): a \(spread.count)-card deal must be \(spread.count) distinct cards")
            }
        }
    }

    // ── the layout: the M7 bar — no overflow on the smallest iPhone ─────────

    /// The card area the 17e (390×844 pt, the smallest supported iPhone)
    /// leaves the table after its chrome — conservative (a bit *smaller*
    /// than the table actually gets), for face-down and revealed states:
    /// width 390 − 28 pt horizontal padding; height 844 − 59 − 34 safe area
    /// − 28 vertical padding − 30 title − 32 picker − 46 button − 64 spacing
    /// − the meaning panel (≈20 pt face-down, ≈180 pt at the 95-char worst
    /// case) → 531 / 377, rounded down to the numbers asserted below.
    static let smallestFaceDown = CGSize(width: 362, height: 500)
    static let smallestRevealed = CGSize(width: 362, height: 340)

    /// The label reservation the table makes for a spread — the labels'
    /// strip sits at the bottom of the card area; the cross labels nothing.
    private func inset(for spread: Spread) -> CGFloat {
        spread.labelsUnderCards ? SpreadLayout.labelInset : 0
    }

    /// The card area after the label reservation (the labels' strip sits at
    /// the bottom of the offered rect).
    private func available(_ spread: Spread, in size: CGSize) -> CGRect {
        CGRect(x: 0, y: 0, width: size.width, height: size.height - inset(for: spread))
    }

    /// Roadmap M7, bar 1: the Celtic cross — ten face-down cards, no
    /// overflow on the smallest iPhone, in both table states.
    func testCelticCrossFitsSmallestiPhone() {
        let cross = Spread.celticCross
        for size in [Self.smallestFaceDown, Self.smallestRevealed] {
            let frames = SpreadLayout.frames(for: cross, in: size, bottomInset: inset(for: cross))
            let avail = available(cross, in: size)
            for (i, f) in frames.enumerated() {
                let vb = visualBox(frames: f, position: cross.positions[i])
                XCTAssertTrue(avail.insetBy(dx: -1, dy: -1).contains(vb),
                              "cross position \(i) (\(cross.positions[i].name)) overflows at \(size)")
            }
        }
    }

    /// The general form of the same bar: every spread fits, both states.
    func testEverySpreadFitsSmallestiPhone() {
        for spread in Spread.all {
            for size in [Self.smallestFaceDown, Self.smallestRevealed] {
                let frames = SpreadLayout.frames(for: spread, in: size, bottomInset: inset(for: spread))
                let avail = available(spread, in: size)
                XCTAssertEqual(frames.count, spread.count)
                for (i, f) in frames.enumerated() {
                    let vb = visualBox(frames: f, position: spread.positions[i])
                    XCTAssertTrue(avail.insetBy(dx: -1, dy: -1).contains(vb),
                                  "\(spread.id) position \(i) overflows at \(size)")
                }
            }
        }
    }

    /// Every card keeps the draft's 9:16 ratio at whatever size it is dealt.
    func testCardsKeepTheirRatio() {
        for spread in Spread.all {
            for size in [Self.smallestFaceDown, Self.smallestRevealed, CGSize(width: 600, height: 800)] {
                for f in SpreadLayout.frames(for: spread, in: size, bottomInset: inset(for: spread)) {
                    XCTAssertEqual(f.height / f.width, 16.0 / 9.0, accuracy: 1e-9,
                                   "\(spread.id): a card must stay 9:16")
                }
            }
        }
    }

    /// The rotation-aware bounding box of a position's card, in points: what
    /// the card *visually* occupies after its `rotationEffect`.
    private func visualBox(frames f: CGRect, position: SpreadPosition) -> CGRect {
        let (bw, bh) = SpreadLayout.bounds(of: position)
        let s = f.width   // one card unit, in points
        return CGRect(x: f.midX - bw / 2 * s, y: f.midY - bh / 2 * s, width: bw * s, height: bh * s)
    }

    /// The crossing card lies perpendicular over the present card — the one
    /// deliberate overlap in the deck; every other pair of positions is
    /// disjoint (the ten cards are separately tappable).
    func testOnlyTheCrossingCardOverlaps() {
        for spread in Spread.all {
            let frames = SpreadLayout.frames(for: spread, in: Self.smallestFaceDown, bottomInset: inset(for: spread))
            for i in frames.indices {
                for j in frames.indices where j > i {
                    let a = visualBox(frames: frames[i], position: spread.positions[i])
                    let b = visualBox(frames: frames[j], position: spread.positions[j])
                    let overlap = a.intersection(b)
                    let area = overlap.isNull ? 0 : overlap.width * overlap.height
                    let sameCenter = spread.positions[i].x == spread.positions[j].x
                                     && spread.positions[i].y == spread.positions[j].y
                    if sameCenter {
                        XCTAssertGreaterThan(area, 0,
                                             "\(spread.id): the stacked pair \(i)/\(j) must actually overlap")
                    } else {
                        XCTAssertLessThan(area, 1.0,
                                          "\(spread.id): positions \(i)/\(j) overlap — cards must be separately tappable")
                    }
                }
            }
        }
    }

    // ── the look: the simple spreads read the way M6's table did ────────────

    /// The three-card spread stays a row of three equal cards, left to right
    /// in deal order — M6's look, just driven by the spec.
    func testThreeCardRowStaysARow() {
        let frames = SpreadLayout.frames(for: Spread.threeCards, in: Self.smallestFaceDown, bottomInset: inset(for: Spread.threeCards))
        XCTAssertEqual(frames.count, 3)
        for i in 1..<3 {
            XCTAssertEqual(frames[i].width, frames[0].width, accuracy: 1e-6, "equal thirds")
            XCTAssertGreaterThan(frames[i].midX, frames[i - 1].midX)
        }
        XCTAssertEqual(frames[0].midY, frames[2].midY, accuracy: 1e-9, "one row")
    }

    /// The single card sits at the center of the space it is given.
    func testOneCardIsCentered() {
        let spread = Spread.oneCard
        let size = Self.smallestFaceDown
        let f = SpreadLayout.frames(for: spread, in: size, bottomInset: inset(for: spread))[0]
        let avail = available(spread, in: size)
        XCTAssertEqual(f.midX, avail.midX, accuracy: 1e-9)
        XCTAssertEqual(f.midY, avail.midY, accuracy: 1e-9)
    }

    /// Bigger space, bigger cards — and the layout stays centered in it.
    func testLayoutScalesWithSpace() {
        for spread in Spread.all {
            let small = SpreadLayout.frames(for: spread, in: Self.smallestFaceDown, bottomInset: inset(for: spread))
            let big = SpreadLayout.frames(for: spread, in: CGSize(width: 700, height: 900), bottomInset: inset(for: spread))
            for i in small.indices {
                XCTAssertGreaterThan(big[i].width, small[i].width, "\(spread.id) should scale up")
            }
            // The laid-out block (rotation-aware) is centered in the available rect.
            let size = CGSize(width: 700, height: 900)
            let avail = available(spread, in: size)
            var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
            var minY = Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
            for (i, f) in big.enumerated() {
                let vb = visualBox(frames: f, position: spread.positions[i])
                minX = min(minX, vb.minX); maxX = max(maxX, vb.maxX)
                minY = min(minY, vb.minY); maxY = max(maxY, vb.maxY)
            }
            XCTAssertEqual((minX + maxX) / 2, avail.midX, accuracy: 1.0)
            XCTAssertEqual((minY + maxY) / 2, avail.midY, accuracy: 1.0)
        }
    }

    // ── the bounding math ────────────────────────────────────────────────────

    /// The rotation-aware box of a 1 × (16/9) card: 0° keeps its shape, 90°
    /// swaps it — the computation the whole fit depends on.
    func testRotationAwareBounds() {
        let h = SpreadLayout.cardHeight
        XCTAssertEqual(SpreadLayout.bounds(of: SpreadPosition(name: "x", prompt: "", x: 0, y: 0)).width, 1, accuracy: 1e-9)
        XCTAssertEqual(SpreadLayout.bounds(of: SpreadPosition(name: "x", prompt: "", x: 0, y: 0)).height, h, accuracy: 1e-9)

        let (w90, h90) = SpreadLayout.bounds(of: SpreadPosition(name: "x", prompt: "", x: 0, y: 0, rotation: 90))
        XCTAssertEqual(w90, h, accuracy: 1e-9)
        XCTAssertEqual(h90, 1, accuracy: 1e-9)

        let r = 45.0 * .pi / 180
        let expected = (cos(r) + sin(r) * h, sin(r) + cos(r) * h)
        let (w45, h45) = SpreadLayout.bounds(of: SpreadPosition(name: "x", prompt: "", x: 0, y: 0, rotation: 45))
        XCTAssertEqual(w45, expected.0, accuracy: 1e-9)
        XCTAssertEqual(h45, expected.1, accuracy: 1e-9)
    }
}

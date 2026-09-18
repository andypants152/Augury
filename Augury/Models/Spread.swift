import Foundation

// MARK: - SpreadPosition

/// One spot in a spread: what it is called, the question it answers, and
/// where it sits on the table.
///
/// `x` / `y` are the card's *center*, in card units — one card unit is the
/// card's own width, so a card occupies 1 × 16/9 of these (the draft's 9:16
/// canvas). `rotation` (degrees, about the card's center) is how the card
/// lies: 0 for everything except the Celtic cross's crossing card, which
/// lies perpendicular over the first, as on a physical table.
struct SpreadPosition: Hashable, Codable {
    let name: String
    let prompt: String
    let x: Double
    let y: Double
    var rotation: Double = 0
}

// MARK: - Spread

/// A spread: the named, prompted positions a reading deals into, in deal
/// order.
///
/// The deal (M5) is order-agnostic — it hands `count` distinct cards — and
/// the table maps `draws[i]` onto `positions[i]`, so the *order of this
/// array is the deal order*: the Celtic cross deals present, crossing,
/// foundation, past, crown, then the staff, exactly as by hand. The layout
/// (where each position sits) is the view's concern, driven through
/// `SpreadLayout` (M7); the spec here is the deck of prompts.
struct Spread: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let positions: [SpreadPosition]

    var count: Int { positions.count }

    /// Whether the table draws each position's name under its card. The big
    /// one- and three-card slots do; the cross's ten cards are too small to
    /// label — the meaning panel names the position instead.
    let labelsUnderCards: Bool

    init(id: String, name: String, positions: [SpreadPosition], labelsUnderCards: Bool = true) {
        self.id = id
        self.name = name
        self.positions = positions
        self.labelsUnderCards = labelsUnderCards
    }
}

// MARK: - The three spreads

extension Spread {

    /// The card's height in card widths — the draft's 540×960 canvas, 9:16.
    /// (Shared with `SpreadLayout`, which scales these specs.)
    static let cardHeight = 16.0 / 9.0

    /// The vertical gap between stacked cards, in card widths (~10% of a
    /// card height) — close enough to read as one spread, open enough to
    /// tap.
    static let rowGap = 0.18

    /// A row's centerline: row `i`, in card units, from the spec's top.
    static func rowCenter(_ i: Int) -> Double {
        Double(i) * (cardHeight + rowGap) + cardHeight / 2
    }

    /// One card: a daily pull — the single answer to the day.
    static let oneCard = Spread(
        id: "one-card",
        name: "One Card",
        positions: [
            SpreadPosition(name: "Today",
                           prompt: "The heart of the matter, as it stands now.",
                           x: 0.5, y: rowCenter(0)),
        ])

    /// Three cards: past / present / future — the M6 spread, unchanged.
    static let threeCards = Spread(
        id: "three-card",
        name: "Three Cards",
        positions: [
            SpreadPosition(name: "Past", prompt: "Where you have come from.",
                           x: 0.5, y: rowCenter(0)),
            SpreadPosition(name: "Present", prompt: "Where you are now.",
                           x: 1.5 + rowGap, y: rowCenter(0)),
            SpreadPosition(name: "Future", prompt: "Where it is leading.",
                           x: 2.5 + 2 * rowGap, y: rowCenter(0)),
        ])

    /// The Celtic cross: the classic ten. The cross takes the left of the
    /// table — crown over the present, the crossing card lying perpendicular
    /// across it, foundation and past below — and the staff of five stands
    /// to the right: near future, self, environment, hopes & fears, outcome.
    /// (Deal order is the array order: the cross first, then the staff.)
    static let celticCross = Spread(
        id: "celtic-cross",
        name: "Celtic Cross",
        positions: [
            SpreadPosition(name: "Present", prompt: "The heart of the matter — what is here now.",
                           x: 1.5, y: rowCenter(1)),
            SpreadPosition(name: "Crossing", prompt: "What crosses it — the challenge that meets it.",
                           x: 1.5, y: rowCenter(1), rotation: 90),
            SpreadPosition(name: "Foundation", prompt: "What lies beneath — the root of it.",
                           x: 1.5, y: rowCenter(2)),
            SpreadPosition(name: "Past", prompt: "What has come before.",
                           x: 1.5, y: rowCenter(3)),
            SpreadPosition(name: "Crown", prompt: "What crowns it — the conscious aim.",
                           x: 1.5, y: rowCenter(0)),
            SpreadPosition(name: "Near Future", prompt: "What is approaching.",
                           x: 4.0, y: rowCenter(0)),
            SpreadPosition(name: "Self", prompt: "Your part in it — how you stand.",
                           x: 4.0, y: rowCenter(1)),
            SpreadPosition(name: "Environment", prompt: "What surrounds it — outside forces.",
                           x: 4.0, y: rowCenter(2)),
            SpreadPosition(name: "Hopes & Fears", prompt: "What you want, what you dread.",
                           x: 4.0, y: rowCenter(3)),
            SpreadPosition(name: "Outcome", prompt: "Where it leads.",
                           x: 4.0, y: rowCenter(4)),
        ],
        labelsUnderCards: false)

    /// Every spread, in picker order: the simple pulls first, the cross last.
    static let all: [Spread] = [oneCard, threeCards, celticCross]
}

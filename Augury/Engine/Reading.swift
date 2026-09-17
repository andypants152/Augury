import Foundation

// MARK: - Orientation

/// How a card falls when it is turned over: upright, or inverted.
///
/// The meaning a reading presents depends on the fall — `Arcana` carries both
/// texts, and the card shows whichever matches. Traditional tarot allows
/// either orientation, and the roadmap defaults to both (open question #2).
enum Orientation: String, Codable, Hashable, CaseIterable {
    case upright
    case inverted

    /// "upright" / "inverted" — for labels and VoiceOver (M6).
    var label: String { rawValue }
}

// MARK: - DrawnCard

/// A card as it lies on the table: its identity plus how it fell.
struct DrawnCard: Hashable, Codable {
    let card: Arcana
    let orientation: Orientation

    /// The meaning this card presents, given how it fell.
    var meaning: String {
        orientation == .upright ? card.upright : card.inverted
    }
}

// MARK: - Reading

/// One reading: the cards a shuffle dealt, in the order they were dealt.
///
/// The order *is* the position — `draws[0]` is the spread's first spot,
/// `draws[1]` the second, and so on. When `Spread` lands (M7) it will name
/// the positions and attach a prompt to each; the engine keeps dealing the
/// same cards in the same order — only the names come later.
///
/// Encodable for the daily journal (M8): a saved entry is the dealt cards +
/// their falls + a date + a note, as local JSON.
struct Reading: Hashable, Codable {
    let draws: [DrawnCard]

    var count: Int { draws.count }
    var cards: [Arcana] { draws.map(\.card) }
}

// MARK: - SeededRNG

/// A deterministic, seedable `RandomNumberGenerator` — splitmix64.
///
/// The stand-in for `SystemRandomNumberGenerator` in tests (a deal must be
/// reproducible to be testable), and the key to a *replayable* reading: same
/// seed, same shuffle, same falls. Splitmix64 is a tiny, well-studied 64-bit
/// mixer — far more uniformity than a card shuffle can demand.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15          // the golden-ratio increment
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - ReadingEngine

/// The one real "random" in Augury: shuffling the deck and dealing it.
///
/// The deck's art and meaning are made once, done; the only things that vary
/// from reading to reading are *which* cards are dealt, *in what order*, and
/// *how each card falls*. All of it flows through this one
/// `RandomNumberGenerator` — the platform CSPRNG in the app, a `SeededRNG` in
/// tests — so every deal is a pure function of (deck, count, seed), and the
/// app has exactly one source of randomness (roadmap M5: "the one real
/// 'random' (a shuffle)").
///
/// **Inject the RNG here; never call `Int.random` / `Bool.random` elsewhere.**
/// Spreads (M7), the journal (M8), and the free tier (M9) all build on this
/// one stream — that is what keeps the whole product testable with a seed
/// instead of hope.
struct ReadingEngine<R: RandomNumberGenerator> {

    /// The single source of randomness for every deal.
    var rng: R

    init(rng: R) {
        self.rng = rng
    }

    /// A Fisher–Yates shuffle of the deck: a uniform random permutation.
    /// Every one of the 78! orderings is equally likely; a card never appears
    /// twice. (`Int.random(in:using:)` does rejection sampling internally, so
    /// each `0...i` pick is *exactly* uniform even though 2^64 does not divide
    /// evenly by `i + 1`.)
    mutating func shuffled(_ deck: [Arcana]) -> [Arcana] {
        var perm = deck
        for i in stride(from: perm.count - 1, to: 0, by: -1) {
            perm.swapAt(i, Int.random(in: 0...i, using: &rng))
        }
        return perm
    }

    /// Shuffle the deck and deal the first `count` cards, in order.
    ///
    /// Shuffling the whole deck first — then taking the top — is the
    /// distribution of "draw `count` without replacement", done the way a
    /// physical reading is done: shuffle, cut, deal.
    ///
    /// Each dealt card lands upright or inverted on its own fair coin,
    /// independent of which card it is and of its neighbours.
    mutating func deal(count: Int, from deck: [Arcana]) -> Reading {
        precondition((0...deck.count).contains(count),
                     "cannot deal \(count) cards from a \(deck.count)-card deck")
        let draws = shuffled(deck).prefix(count).map {
            DrawnCard(card: $0,
                      orientation: Bool.random(using: &rng) ? .upright : .inverted)
        }
        return Reading(draws: draws)
    }
}

extension ReadingEngine where R == SystemRandomNumberGenerator {
    /// The app's engine: the platform CSPRNG — live, unpredictable shuffles.
    init() {
        self.init(rng: SystemRandomNumberGenerator())
    }
}

extension ReadingEngine where R == SeededRNG {
    /// A reproducible engine: same seed, same deals (tests, replays).
    init(seed: UInt64) {
        self.init(rng: SeededRNG(seed: seed))
    }
}

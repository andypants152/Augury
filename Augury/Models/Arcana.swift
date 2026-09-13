import Foundation

// MARK: - Suit

/// The four minor-arcana suits, each mapping to an element. Majors carry no suit.
enum Suit: Int, CaseIterable, Codable, Hashable {
    case wands = 0
    case cups = 1
    case swords = 2
    case pentacles = 3

    var element: String {
        switch self {
        case .wands: return "fire"
        case .cups: return "water"
        case .swords: return "air"
        case .pentacles: return "earth"
        }
    }

    var displayName: String {
        switch self {
        case .wands: return "Wands"
        case .cups: return "Cups"
        case .swords: return "Swords"
        case .pentacles: return "Pentacles"
        }
    }
}

// MARK: - ArcanaID

/// Stable, type-safe identity for each of the 78 cards.
///
/// Majors are `0`–`21`. Minors run `22`–`77` in suit blocks of 14:
/// Wands `22`–`35`, Cups `36`–`49`, Swords `50`–`63`, Pentacles `64`–`77`.
/// The raw value is the card's deck position, which keeps the shuffle and the
/// "22 majors / 56 minors" split easy to derive.
enum ArcanaID: Int, CaseIterable, Codable, Hashable {

    // Major arcana (0–21)
    case fool, magician, highPriestess, empress, emperor, hierophant, lovers, chariot,
        strength, hermit, wheelOfFortune, justice, hangedMan, death, temperance, devil,
        tower, star, moon, sun, judgement, world

    // Wands (22–35)
    case wandsAce, wandsTwo, wandsThree, wandsFour, wandsFive, wandsSix, wandsSeven,
        wandsEight, wandsNine, wandsTen, wandsPage, wandsKnight, wandsQueen, wandsKing

    // Cups (36–49)
    case cupsAce, cupsTwo, cupsThree, cupsFour, cupsFive, cupsSix, cupsSeven,
        cupsEight, cupsNine, cupsTen, cupsPage, cupsKnight, cupsQueen, cupsKing

    // Swords (50–63)
    case swordsAce, swordsTwo, swordsThree, swordsFour, swordsFive, swordsSix, swordsSeven,
        swordsEight, swordsNine, swordsTen, swordsPage, swordsKnight, swordsQueen, swordsKing

    // Pentacles (64–77)
    case pentaclesAce, pentaclesTwo, pentaclesThree, pentaclesFour, pentaclesFive,
        pentaclesSix, pentaclesSeven, pentaclesEight, pentaclesNine, pentaclesTen,
        pentaclesPage, pentaclesKnight, pentaclesQueen, pentaclesKing

    /// First minor's raw value — the major/minor boundary.
    static let majorCount: Int = 22

    /// `true` for the 22 major arcana.
    var isMajor: Bool { rawValue < Self.majorCount }

    /// The suit for a minor card; `nil` for majors.
    var suit: Suit? {
        guard !isMajor else { return nil }
        return Suit(rawValue: (rawValue - Self.majorCount) / 14)
    }
}

// MARK: - Arcana

/// One card of the deck: a fixed identity plus the content that makes it a card.
///
/// The *art* (celestial line-art SVG + holographic finish) is a separate concern
/// applied at render time; here the card is its identity and its words. Made once, done.
struct Arcana: Identifiable, Codable, Hashable {
    let id: ArcanaID
    let name: String
    let keywords: [String]
    let upright: String
    let inverted: String

    var isMajor: Bool { id.isMajor }
    var suit: Suit? { id.suit }

    /// The element for a minor (its suit's element); `nil` for majors.
    var element: String? { suit?.element }

    /// The asset-catalog name of this card's line-art layer in `Assets.xcassets`
    /// — must match the draft file name exactly, or the card renders blank.
    ///
    /// Majors are named from the display name (its file slug): "The High
    /// Priestess" → `the-high-priestess`, "Strength" → `strength` — no forced
    /// `the-` prefix, since six majors (Strength, Wheel of Fortune, Justice,
    /// Death, Temperance, Judgement) traditionally take no article. Minors are
    /// `suit-rank` from the id: `wandsAce` → `wands-ace`.
    var assetName: String {
        if isMajor {
            return name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "\u{2019}", with: "")
                .replacingOccurrences(of: "'", with: "")
        }
        var out = ""
        for ch in String(describing: id) {
            if ch.isUppercase { out += "-\(ch.lowercased())" } else { out.append(ch) }
        }
        return out
    }
}

import Foundation

// MARK: - ArcanaCatalog
//
// The complete deck: all 78 cards. Each is a fixed identity + its words.
// This is *content*, authored once and committed — the "made once, done" layer.
// (The celestial line-art SVG and holo finish that dress each card are separate,
// render-time concerns; see M2–M3 and M4.)

extension Arcana {

    /// The full 78-card deck, in deck order (majors, then Wands/Cups/Swords/Pentacles).
    static let all: [Arcana] = [
        // ─────────────────────────── MAJOR ARCANA (22) ───────────────────────────

        Arcana(id: .fool, name: "The Fool",
               keywords: ["new beginnings", "innocence", "spontaneity", "free spirit"],
               upright: "A fresh start with boundless optimism — a leap into the unknown, made with faith and lightness.",
               inverted: "A step held back by fear, or a leap taken without looking; recklessness and naivety."),

        Arcana(id: .magician, name: "The Magician",
               keywords: ["willpower", "creativity", "resourcefulness", "manifestation"],
               upright: "You have the tools and the will to make it happen; focused intention brings things into form.",
               inverted: "Wasted or misdirected talent; manipulation, or power that is not being used."),

        Arcana(id: .highPriestess, name: "The High Priestess",
               keywords: ["intuition", "mystery", "inner voice", "stillness"],
               upright: "Listen beneath the noise; the answer is known, not spoken. Patience and inner knowing.",
               inverted: "Ignoring your intuition; secrets, confusion, or a surface busy-ness that hides the truth."),

        Arcana(id: .empress, name: "The Empress",
               keywords: ["nurture", "abundance", "fertility", "sensory pleasure"],
               upright: "Growth, plenty, and care; the lush, generative side of life in full bloom.",
               inverted: "Creativity or nurturing blocked; smothering, neglect, or a dependence that stunts growth."),

        Arcana(id: .emperor, name: "The Emperor",
               keywords: ["structure", "authority", "stability", "foundation"],
               upright: "Order, discipline, and a steady hand; building something that will last.",
               inverted: "Rigidity or domination; control that has quietly become control *of* you."),

        Arcana(id: .hierophant, name: "The Hierophant",
               keywords: ["tradition", "guidance", "institutions", "shared belief"],
               upright: "Wisdom passed down; a mentor, a tradition, or the comfort of a familiar path.",
               inverted: "Challenging the establishment; dogma that no longer serves, a need to find your own way."),

        Arcana(id: .lovers, name: "The Lovers",
               keywords: ["choice", "alignment", "partnership", "values"],
               upright: "A meaningful choice made from the heart; union, harmony, and values in alignment.",
               inverted: "Discord or a choice avoided; a relationship or decision out of balance."),

        Arcana(id: .chariot, name: "The Chariot",
               keywords: ["will", "determination", "direction", "triumph"],
               upright: "Forward momentum through sheer will; opposing forces harnessed toward a single aim.",
               inverted: "Loss of direction; force without focus, or a will that has lost its target."),

        Arcana(id: .strength, name: "Strength",
               keywords: ["courage", "gentle power", "compassion", "patience"],
               upright: "Soft power over brute force; quiet courage and compassion that tames the wild.",
               inverted: "Self-doubt, or raw force; a battle that cannot be won by strength alone."),

        Arcana(id: .hermit, name: "The Hermit",
               keywords: ["solitude", "introspection", "wisdom", "withdrawal"],
               upright: "A deliberate pause to find your way; wisdom sought in quiet, a light held for yourself.",
               inverted: "Isolation that turns to loneliness; hiding from the answer, withdrawal without purpose."),

        Arcana(id: .wheelOfFortune, name: "Wheel of Fortune",
               keywords: ["cycles", "change", "fate", "turning point"],
               upright: "A turn in the cycle; change is moving, and with it comes a new set of possibilities.",
               inverted: "Resistance to change; a cycle that will not turn, or luck that has run its course."),

        Arcana(id: .justice, name: "Justice",
               keywords: ["fairness", "truth", "cause and effect", "accountability"],
               upright: "Truth and consequence in balance; a fair reckoning, a decision made on the evidence.",
               inverted: "Avoiding accountability; bias, injustice, or outcomes that do not add up."),

        Arcana(id: .hangedMan, name: "The Hanged Man",
               keywords: ["surrender", "new perspective", "pause", "letting go"],
               upright: "A voluntary pause; seeing the world upside down, yielding in order to gain a new view.",
               inverted: "Stuck without cause; a delay that has stopped being useful, or a martyrdom of self."),

        Arcana(id: .death, name: "Death",
               keywords: ["endings", "transition", "transformation", "release"],
               upright: "An ending that clears the ground; what must die so that the next thing can live.",
               inverted: "Clinging to what is over; a transition resisted, a change that will not be let in."),

        Arcana(id: .temperance, name: "Temperance",
               keywords: ["balance", "moderation", "patience", "integration"],
               upright: "The middle way; blending opposites into something whole, patience that turns lead to gold.",
               inverted: "Excess or imbalance; a forced mixture, or patience that has tipped into stagnation."),

        Arcana(id: .devil, name: "The Devil",
               keywords: ["bondage", "desire", "shadow", "pattern"],
               upright: "A chain you can see and still will not remove; desire, habit, or a pattern that binds.",
               inverted: "Breaking free; the chain loosens, and the shadow is named and met."),

        Arcana(id: .tower, name: "The Tower",
               keywords: ["upheaval", "revelation", "sudden change", "awakening"],
               upright: "A sudden, forceful breaking-down; the false structure falls and the truth is revealed.",
               inverted: "A collapse foreseen or delayed; the shock is coming, or its lessons are being resisted."),

        Arcana(id: .star, name: "The Star",
               keywords: ["hope", "renewal", "serenity", "purpose"],
               upright: "Calm after the storm; quiet hope, renewal, and a sense of being guided.",
               inverted: "A faltering of faith; disconnection from hope, or a wish unmoored from action."),

        Arcana(id: .moon, name: "The Moon",
               keywords: ["illusion", "the unconscious", "fear", "dreams"],
               upright: "The landscape of dreams and doubt; not everything is as it seems, and fear fills the dark.",
               inverted: "Clarity emerging; the fog thins, illusions resolve, and the hidden is brought to light."),

        Arcana(id: .sun, name: "The Sun",
               keywords: ["joy", "vitality", "success", "clarity"],
               upright: "Light, warmth, and unclouded joy; success, vitality, and things exactly as they are.",
               inverted: "A temporary dimming; joy momentarily clouded, or success that feels just out of reach."),

        Arcana(id: .judgement, name: "Judgement",
               keywords: ["reckoning", "calling", "absolution", "awakening"],
               upright: "A clearing of the score; a calling answered, a reckoning that frees and renews.",
               inverted: "Self-judgement that will not release; a calling ignored, the past held too tightly."),

        Arcana(id: .world, name: "The World",
               keywords: ["completion", "integration", "accomplishment", "wholeness"],
               upright: "A cycle complete; wholeness, accomplishment, and the door to the next great cycle.",
               inverted: "A finish just out of reach; something left unfinished, or a closure resisted."),

        // ─────────────────────────── WANDS — fire (14) ───────────────────────────

        Arcana(id: .wandsAce, name: "Ace of Wands",
               keywords: ["inspiration", "new opportunity", "potential"],
               upright: "A spark of inspiration; a new venture, opportunity, or creative impulse taking fire.",
               inverted: "A stalled start; delayed or blocked initiative, enthusiasm that fizzles."),

        Arcana(id: .wandsTwo, name: "Two of Wands",
               keywords: ["planning", "foresight", "ambition"],
               upright: "Looking out from your domain toward what is next; planning the move, holding the map.",
               inverted: "Fear of the next step; plans that stay on the shelf, ambition held back."),

        Arcana(id: .wandsThree, name: "Three of Wands",
               keywords: ["expansion", "progress", "anticipation"],
               upright: "Plans set out to sea; progress, expansion, and the anticipation of their return.",
               inverted: "Delays; expansion that does not come, or looking outward while the base is unsecured."),

        Arcana(id: .wandsFour, name: "Four of Wands",
               keywords: ["harmony", "celebration", "home"],
               upright: "A homecoming and a celebration; stability, community, and a milestone shared.",
               inverted: "A hollow celebration; instability at home, or a harmony that is only a surface."),

        Arcana(id: .wandsFive, name: "Five of Wands",
               keywords: ["conflict", "competition", "challenge"],
               upright: "A scuffle of ideas; competition, friction, and a challenge that tests your mettle.",
               inverted: "Standing down; the conflict resolves or is avoided, tension at last released."),

        Arcana(id: .wandsSix, name: "Six of Wands",
               keywords: ["victory", "recognition", "confidence"],
               upright: "A public victory; recognition, confidence, and being led — or leading — in triumph.",
               inverted: "Ego, or a hard-won fall; recognition withheld, a victory that costs something."),

        Arcana(id: .wandsSeven, name: "Seven of Wands",
               keywords: ["defense", "perseverance", "standing your ground"],
               upright: "Holding your ground; defending a position or an idea against the pressure to yield.",
               inverted: "Overwhelmed or overextended; a stand that is becoming a siege."),

        Arcana(id: .wandsEight, name: "Eight of Wands",
               keywords: ["swift movement", "momentum", "travel"],
               upright: "Fast motion; events arriving quickly, travel, and a momentum that carries you.",
               inverted: "A bottleneck; momentum blocked, delay, or haste that leads nowhere."),

        Arcana(id: .wandsNine, name: "Nine of Wands",
               keywords: ["resilience", "guard", "last stand"],
               upright: "Wounded but standing; the last stretch of a long fight, guarded and resolute.",
               inverted: "Exhaustion; a guard that has worn you down more than the enemy did."),

        Arcana(id: .wandsTen, name: "Ten of Wands",
               keywords: ["burden", "responsibility", "completion"],
               upright: "Carrying too much; a heavy load you are responsible for, and near the end of the road.",
               inverted: "Setting the load down; delegation, release, or a burden that finally gets put away."),

        Arcana(id: .wandsPage, name: "Page of Wands",
               keywords: ["enthusiasm", "discovery", "a new idea"],
               upright: "An eager scout; enthusiasm, a new idea, and the thrill of a discovery to explore.",
               inverted: "Delayed or aimless enthusiasm; a message not received, excitement without a target."),

        Arcana(id: .wandsKnight, name: "Knight of Wands",
               keywords: ["adventure", "energy", "boldness"],
               upright: "A bold rider at full gallop; passionate, impulsive action and a love of the open road.",
               inverted: "A reckless gallop; burnout, haste, or energy with no direction."),

        Arcana(id: .wandsQueen, name: "Queen of Wands",
               keywords: ["confidence", "warmth", "self-assurance"],
               upright: "Warm, confident, and magnetic; a person who owns her fire and lights the room.",
               inverted: "Jealousy or burnout; a confidence that curdles into demanding attention."),

        Arcana(id: .wandsKing, name: "King of Wands",
               keywords: ["visionary", "leadership", "enterprise"],
               upright: "A visionary leader; decisive, charismatic, and willing to build and risk.",
               inverted: "Impulsive or domineering; a leader who burns what he builds."),

        // ─────────────────────────── CUPS — water (14) ───────────────────────────

        Arcana(id: .cupsAce, name: "Ace of Cups",
               keywords: ["new love", "compassion", "emotional beginning"],
               upright: "A new emotional beginning; love, compassion, and a feeling offered freely.",
               inverted: "An emotional blockage; a feeling withheld or spilled, a heart not ready to receive."),

        Arcana(id: .cupsTwo, name: "Two of Cups",
               keywords: ["partnership", "connection", "mutual love"],
               upright: "Two who meet as equals; a genuine bond, mutual affection, and partnership.",
               inverted: "A waning bond; an imbalance in a relationship, or a connection that is cooling."),

        Arcana(id: .cupsThree, name: "Three of Cups",
               keywords: ["friendship", "celebration", "community"],
               upright: "Friends gathered in celebration; joy, community, and shared emotion.",
               inverted: "Overindulgence or isolation; a gathering that turns to gossip, or missing the crowd."),

        Arcana(id: .cupsFour, name: "Four of Cups",
               keywords: ["apathy", "contemplation", "disconnection"],
               upright: "A moment of boredom or withdrawal; gifts unseen, a need to step back and reflect.",
               inverted: "Waking from apathy; accepting what has been offered, engagement returning."),

        Arcana(id: .cupsFive, name: "Five of Cups",
               keywords: ["loss", "grief", "regret"],
               upright: "Grief for what has spilled; disappointment and loss, though not everything is gone.",
               inverted: "Letting go of grief; the remaining cups seen at last, consolation and recovery."),

        Arcana(id: .cupsSix, name: "Six of Cups",
               keywords: ["nostalgia", "innocence", "reunion"],
               upright: "A fond look back; nostalgia, innocent joy, and a reunion or a gift from the past.",
               inverted: "Living in the past; an idealized memory, or a kindness that cannot be repeated."),

        Arcana(id: .cupsSeven, name: "Seven of Cups",
               keywords: ["choices", "illusion", "wishful thinking"],
               upright: "Many paths, few real; choices that shimmer, fantasy over substance.",
               inverted: "A choice made; the illusions clear, and you pick the real one at last."),

        Arcana(id: .cupsEight, name: "Eight of Cups",
               keywords: ["withdrawal", "quest", "disillusionment"],
               upright: "Walking away; leaving what no longer serves, a quiet quest for something deeper.",
               inverted: "Fear of the walk; staying in what is empty, or a quest that will not begin."),

        Arcana(id: .cupsNine, name: "Nine of Cups",
               keywords: ["contentment", "satisfaction", "gratitude"],
               upright: "Wishes fulfilled; contentment, satisfaction, and a quiet emotional plenty.",
               inverted: "A hollow plenty; satisfaction that does not satisfy, or a wishful fulfillment."),

        Arcana(id: .cupsTen, name: "Ten of Cups",
               keywords: ["harmony", "family", "fulfillment"],
               upright: "Emotional fulfillment; a harmonious home, family, and lasting happiness.",
               inverted: "A fractured harmony; family tension, or a happiness that leaves someone out."),

        Arcana(id: .cupsPage, name: "Page of Cups",
               keywords: ["intuition", "imagination", "a new message"],
               upright: "A new feeling or message; intuition, a creative spark, an offer of the heart.",
               inverted: "A message unheeded; moodiness, or an imagination that stays inward."),

        Arcana(id: .cupsKnight, name: "Knight of Cups",
               keywords: ["romance", "invitation", "idealism"],
               upright: "An offer of the heart; romance, an invitation, and a charming, idealistic pursuit.",
               inverted: "An offer that is empty; romance that is all performance, or an invitation declined."),

        Arcana(id: .cupsQueen, name: "Queen of Cups",
               keywords: ["compassion", "intuition", "emotional depth"],
               upright: "Deep compassion and emotional wisdom; nurturing, empathic, and quietly intuitive.",
               inverted: "Over-giving or a closed heart; compassion turned to codependence, or feeling shut off."),

        Arcana(id: .cupsKing, name: "King of Cups",
               keywords: ["emotional mastery", "diplomacy", "calm"],
               upright: "Emotion held with mastery; calm, diplomatic, and compassionate under any weather.",
               inverted: "Emotion that floods or freezes; moodiness, manipulation, or a heart gone cold."),

        // ─────────────────────────── SWORDS — air (14) ───────────────────────────

        Arcana(id: .swordsAce, name: "Ace of Swords",
               keywords: ["clarity", "insight", "breakthrough"],
               upright: "A sharp new truth; clarity, a breakthrough insight, and an idea that cuts through.",
               inverted: "A muddled edge; confusion, a truth twisted, or a breakthrough that is missed."),

        Arcana(id: .swordsTwo, name: "Two of Swords",
               keywords: ["decision", "stalemate", "avoidance"],
               upright: "A blindfolded standoff; a decision deferred, an impasse, weighing two paths.",
               inverted: "The bandage comes off; the avoided decision met, and clarity at last."),

        Arcana(id: .swordsThree, name: "Three of Swords",
               keywords: ["heartbreak", "grief", "a painful truth"],
               upright: "A clean, painful cut; heartbreak, sorrow, and a truth that hurts to know.",
               inverted: "The wound beginning to heal; grief working through, separation, or relief."),

        Arcana(id: .swordsFour, name: "Four of Swords",
               keywords: ["rest", "recovery", "stillness"],
               upright: "A necessary rest; recovery, stillness, and a pause to gather strength.",
               inverted: "Restlessness; a pause that becomes avoidance, or rest that simply will not come."),

        Arcana(id: .swordsFive, name: "Five of Swords",
               keywords: ["conflict", "defeat", "empty victory"],
               upright: "A hollow win; conflict and pride, a victory that costs the relationship.",
               inverted: "Making amends; the conflict released, or the pride finally set down."),

        Arcana(id: .swordsSix, name: "Six of Swords",
               keywords: ["transition", "moving on", "departure"],
               upright: "Crossing to calmer water; a transition, moving on, and leaving trouble behind.",
               inverted: "A crossing that will not come; resistance to a needed move, or a troubled return."),

        Arcana(id: .swordsSeven, name: "Seven of Swords",
               keywords: ["deception", "strategy", "stealth"],
               upright: "A quiet retreat; strategy, a shortcut, and a truth not fully told.",
               inverted: "The plan exposed; deception met, or a strategy that turns honest."),

        Arcana(id: .swordsEight, name: "Eight of Swords",
               keywords: ["entrapment", "self-doubt", "limitation"],
               upright: "Bound by your own belief; feeling trapped, though the bonds are looser than they seem.",
               inverted: "The bindings come off; a limit recognized as self-made, and freedom found."),

        Arcana(id: .swordsNine, name: "Nine of Swords",
               keywords: ["anxiety", "worry", "regret"],
               upright: "A mind at 3 a.m.; anxiety, regret, and a fear that loudens in the dark.",
               inverted: "The worry easing; relief, the worst of it passed, and sleep returning."),

        Arcana(id: .swordsTen, name: "Ten of Swords",
               keywords: ["ending", "rock bottom", "finality"],
               upright: "The final wound; an ending, rock bottom, and the last of a cycle that cannot get worse.",
               inverted: "Recovery; the end is past, and what remains is only the way up."),

        Arcana(id: .swordsPage, name: "Page of Swords",
               keywords: ["vigilance", "curiosity", "a new idea"],
               upright: "A sharp young mind; alertness, a new idea, and a truth just noticed.",
               inverted: "A suspicious edge; gossip, a premature conclusion, or watchfulness turned to doubt."),

        Arcana(id: .swordsKnight, name: "Knight of Swords",
               keywords: ["drive", "decisiveness", "force"],
               upright: "A charge at full speed; decisive and driven, unafraid to act on the mind's edge.",
               inverted: "A reckless charge; haste, conflict, or action that outruns its thought."),

        Arcana(id: .swordsQueen, name: "Queen of Swords",
               keywords: ["clarity", "independence", "boundaries"],
               upright: "A clear, independent mind; honest speech and boundaries that protect.",
               inverted: "A mind that cuts too deep; cynicism, coldness, or walls that shut everyone out."),

        Arcana(id: .swordsKing, name: "King of Swords",
               keywords: ["intellect", "justice", "objectivity"],
               upright: "Ruling by reason; objective, fair, and a mind that sees the whole board.",
               inverted: "Reason that rules without feeling; tyranny, dogma, or intellect weaponized."),

        // ─────────────────────────── PENTACLES — earth (14) ───────────────────────────

        Arcana(id: .pentaclesAce, name: "Ace of Pentacles",
               keywords: ["new opportunity", "prosperity", "a solid start"],
               upright: "A seed of plenty; a new material opportunity, prosperity, and a chance to grow something real.",
               inverted: "A seed that will not take; a missed opportunity, or wealth that slips through the hands."),

        Arcana(id: .pentaclesTwo, name: "Two of Pentacles",
               keywords: ["balance", "adaptability", "priorities"],
               upright: "Juggling with skill; balance, adaptability, and managing competing demands.",
               inverted: "A dropped ball; overload, imbalance, or priorities that cannot be met."),

        Arcana(id: .pentaclesThree, name: "Three of Pentacles",
               keywords: ["teamwork", "craft", "quality"],
               upright: "Craft shared; teamwork, skilled collaboration, and work that is done well together.",
               inverted: "Disjointed work; a lack of skill or cooperation, or credit not shared."),

        Arcana(id: .pentaclesFour, name: "Four of Pentacles",
               keywords: ["security", "control", "possession"],
               upright: "Holding fast; security, control, and a firm grip on what you have.",
               inverted: "A loosened grip; release and generosity, or the quiet cost of holding on too tight."),

        Arcana(id: .pentaclesFive, name: "Five of Pentacles",
               keywords: ["hardship", "loss", "isolation"],
               upright: "Walking past the open door in want; hardship, loss, and feeling left out in the cold.",
               inverted: "The door finally seen; recovery, help accepted, and an end to the deprivation."),

        Arcana(id: .pentaclesSix, name: "Six of Pentacles",
               keywords: ["generosity", "giving", "balance"],
               upright: "Giving and receiving in balance; generosity, charity, and a fair sharing of resources.",
               inverted: "Giving that keeps score; a lopsided exchange, or pride that will not accept help."),

        Arcana(id: .pentaclesSeven, name: "Seven of Pentacles",
               keywords: ["patience", "investment", "assessment"],
               upright: "Tending what you have planted; patience, investment, and the slow work of growth.",
               inverted: "Impatience; a return that is overdue, or an investment that is not paying off."),

        Arcana(id: .pentaclesEight, name: "Eight of Pentacles",
               keywords: ["diligence", "practice", "mastery"],
               upright: "Worked by hand; diligence, practice, and the quiet building of a skill.",
               inverted: "A dropped chisel; burnout, poor work, or drudgery without mastery."),

        Arcana(id: .pentaclesNine, name: "Nine of Pentacles",
               keywords: ["abundance", "self-sufficiency", "reward"],
               upright: "The harvest enjoyed; abundance, ease, and the quiet rewards of your own effort.",
               inverted: "A harvest not yet; a premature enjoyment, or abundance that feels unearned."),

        Arcana(id: .pentaclesTen, name: "Ten of Pentacles",
               keywords: ["wealth", "legacy", "security"],
               upright: "Wealth that outlives you; legacy, family, and long-term security.",
               inverted: "A legacy in question; family wealth disputed, or security that is only on paper."),

        Arcana(id: .pentaclesPage, name: "Page of Pentacles",
               keywords: ["opportunity", "focus", "study"],
               upright: "A new practical opportunity; focus, study, and a venture worth tending.",
               inverted: "A distracted mind; a missed opportunity, or focus that drifts."),

        Arcana(id: .pentaclesKnight, name: "Knight of Pentacles",
               keywords: ["diligence", "method", "reliability"],
               upright: "A slow, sure ride; reliability, method, and progress that is steady if not fast.",
               inverted: "A stalled horse; stagnation, routine, or patience that has turned to inertia."),

        Arcana(id: .pentaclesQueen, name: "Queen of Pentacles",
               keywords: ["nurture", "practical", "security"],
               upright: "Nurturing the material world; practical, secure, and generous with what she has.",
               inverted: "A neglected garden; over-giving, or a practicality that tips into scarcity."),

        Arcana(id: .pentaclesKing, name: "King of Pentacles",
               keywords: ["prosperity", "stability", "provision"],
               upright: "Ruling the material; prosperous, stable, and a provider who builds to last.",
               inverted: "A grip that turns to greed; instability, miserliness, or wealth that corrupts."),
    ]
}

import SwiftUI

/// The table (M6): a three-card reading — past / present / future.
///
/// The ritual: launch deals the three cards face-down (the deal is the
/// shuffle — M5, the one real random); tap a card to flip it over, and it
/// reveals its line art **under the holographic finish** with its (upright
/// or inverted) meaning in the panel below; "New reading" sweeps the table
/// and deals a fresh three.
///
/// Roadmap M6, done-when: **≤ 3 taps from cold launch to the first revealed
/// (holo) card** — met with room to spare, since the deal is automatic on
/// launch and one tap flips the first card over. Every card is a single
/// VoiceOver element labeled with its position, name, and fall.
///
/// The holo + CoreMotion stay live only while at least one card is face-up
/// **and** the scene is active (roadmap M4: no idle draw; Reduce Motion →
/// the frozen sheen). M7 will generalize this to all spreads; the 3-card
/// past/present/future layout is deliberately simple — three equal slots,
/// which cannot overflow the smallest iPhone.
struct ReadingTable: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// One shared motion source for the whole table: CoreMotion starts while
    /// any card is revealed, stops when none are — three cards, one sensor.
    @StateObject private var tilt = MotionTilt()

    private let deck = Arcana.all

    /// The three spread positions, in deal order. (`Spread`, M7, will own
    /// these names + prompts for all spreads.)
    private let positions = ["Past", "Present", "Future"]

    /// The dealt reading — three `DrawnCard`s, each with its fall (M5).
    @State private var reading: Reading?
    /// Which positions are face-up.
    @State private var revealed: Set<Int> = []
    /// The position whose meaning the panel shows — the last one tapped.
    @State private var focus: Int?

    /// A card that is up *and* whose scene is active: the holo/motion state.
    private var live: Bool { !revealed.isEmpty && scenePhase == .active }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Three Cards")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 4)

                cardRow
                    .padding(.horizontal, 14)

                meaningPanel

                Button(action: newReading) {
                    Label("New reading", systemImage: "arrow.triangle.2.circlepath")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15)))
                }
                .padding(.bottom, 6)
            }
            .padding(.vertical, 14)
        }
        .onAppear {
            if reading == nil { deal() }     // the deal is automatic — the ritual starts on launch
            #if DEBUG
            applyDebugHook()
            #endif
        }
        .onChange(of: live) { _, isLive in
            tilt.setFaceUp(isLive)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: The three slots

    private var cardRow: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                cardSlot(i)
                    .frame(maxWidth: .infinity)   // equal thirds — no overflow on any iPhone
            }
        }
    }

    private func cardSlot(_ i: Int) -> some View {
        let isUp = revealed.contains(i)
        let drawn = reading?.draws[i]
        return VStack(spacing: 8) {
            RevealCard(card: drawn?.card ?? deck[0],
                        faceUp: isUp,
                        reduceMotion: reduceMotion,
                        tilt: tilt,
                        isFaceUp: isUp && scenePhase == .active)
            Text(positions[i])
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(isUp ? 0.85 : 0.45))
                .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { tap(i) }
        // One VoiceOver element per card (roadmap M6: every card labeled).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(i, drawn: drawn, isUp: isUp))
        .accessibilityAddTraits(.isButton)
    }

    private func label(_ i: Int, drawn: DrawnCard?, isUp: Bool) -> String {
        let position = positions[i]
        guard isUp, let drawn else {
            return "\(position) card, face down. Double tap to reveal."
        }
        let fall = drawn.orientation == .inverted ? ", inverted" : ""
        return "\(position) card: \(drawn.card.name)\(fall), revealed. Double tap to show its meaning."
    }

    // MARK: The meaning panel

    @ViewBuilder
    private var meaningPanel: some View {
        if let f = focus, f < 3, let drawn = reading?.draws[f] {
            VStack(spacing: 8) {
                Text(positions[f])
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.45))
                Text(drawn.card.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(drawn.orientation.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(drawn.orientation == .upright ? Self.uprightInk : Self.invertedInk)
                Text(drawn.meaning)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(positions[f]): \(drawn.card.name), \(drawn.orientation.label). \(drawn.meaning)")
            .accessibilityAddTraits(.isStaticText)
        } else if reading != nil {
            Text("Tap a card to reveal it")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.4))
                .accessibilityHidden(true)   // the cards' own labels carry the affordance
        }
    }

    /// The deck's own palette (see `generate.py`): gold for the upright,
    /// starlight-silver for the inverted.
    static let uprightInk = Color(red: 0.90, green: 0.78, blue: 0.61)
    static let invertedInk = Color(red: 0.72, green: 0.75, blue: 0.85)

    // MARK: Actions

    /// Tap a slot: a face-down card flips over (its fall was decided at
    /// deal time — M5); a revealed card simply re-focuses, so its meaning
    /// can be re-read without losing the card.
    private func tap(_ i: Int) {
        guard reading != nil else { return }
        focus = i
        if !revealed.contains(i) {
            withAnimation(flip) {
                _ = revealed.insert(i)   // `insert` returns a tuple; discard it
            }
        }
    }

    /// "New reading": deal a fresh three, all face-down. The revealed cards
    /// flip back over (the new art is hidden under the backs until flipped).
    private func newReading() {
        withAnimation(flip) { deal() }
    }

    private func deal() {
        // A fresh engine per deal (M5): the platform CSPRNG, one shuffle.
        // Not stored — a fresh CSPRNG is just as random, and keeping it local
        // keeps `deal()` non-mutating (it only touches `@State`), so it works
        // from `onAppear` and the button alike. The free-tier deck swap (M9)
        // belongs in this one line.
        var engine = ReadingEngine()
        reading = engine.deal(count: 3, from: deck)
        revealed = []
        focus = nil
    }

    /// Under Reduce Motion: a plain crossfade instead of a 3D flip
    /// (vestibular safety) — the holo is likewise frozen (see `HoloLayer`).
    private var flip: Animation {
        reduceMotion ? .easeInOut(duration: 0.35) : .spring(response: 0.5, dampingFraction: 0.8)
    }

    // MARK: Verification hook

    #if DEBUG
    /// Launch arguments for screenshot passes (the M4 hook, carried forward):
    ///   `-auguryCard <slug>` — force the first position to a known arcana
    ///                          (its assetName), so a worst-case card can be
    ///                          pinned, e.g. `-auguryCard the-high-priestess`
    ///   `-auguryRevealed`    — reveal all three (holo + meaning panel)
    ///   `-auguryInverted`    — force all three to fall inverted
    private func applyDebugHook() {
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("-auguryCard") }),
           arg.count > "-auguryCard=".count,
           let r = reading {
            let slug = String(arg.dropFirst("-auguryCard=".count))
            if let idx = deck.firstIndex(where: { $0.assetName == slug }) {
                var draws = r.draws
                draws[0] = DrawnCard(card: deck[idx], orientation: .upright)
                reading = Reading(draws: draws)
            }
        }
        if CommandLine.arguments.contains("-auguryInverted"), let r = reading {
            reading = Reading(draws: r.draws.map { DrawnCard(card: $0.card, orientation: .inverted) })
        }
        if CommandLine.arguments.contains("-auguryRevealed") {
            revealed = [0, 1, 2]
            focus = 0
        }
    }
    #endif
}

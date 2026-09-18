import SwiftUI

/// The table (M6, spread-driven in M7): a spread dealt face-down through
/// the M5 engine — one card, three (past / present / future), or the Celtic
/// cross — tap a card to flip it over, and it reveals its line art **under
/// the holographic finish** with its (upright or inverted) meaning in the
/// panel below; "New reading" sweeps the table and deals the same spread
/// fresh.
///
/// M7 generalizes M6's hard-coded 3-slot row: the table is driven by
/// `Spread` (`Models/Spread.swift`) — its positions name the spots, carry a
/// prompt, and specify the layout in card units — and `SpreadLayout` scales
/// the spec to fit whatever space the panel leaves, so the cross's ten
/// face-down cards fit the smallest iPhone by construction (unit-tested in
/// `SpreadTests`, screenshot-verified on the 17e).
///
/// Carried over from M6: the deal is automatic on launch — **one tap** from
/// cold launch to the first revealed (holo) card; every card is a single
/// VoiceOver element (position + name + fall); the holo + CoreMotion stay
/// live only while at least one card is face-up **and** the scene is
/// active (no idle draw; Reduce Motion → the frozen sheen); one shared
/// `MotionTilt` for the whole table.
struct ReadingTable: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// One shared motion source for the whole table: CoreMotion starts while
    /// any card is revealed, stops when none are — ten cards, one sensor.
    @StateObject private var tilt = MotionTilt()

    private let deck = Arcana.all

    /// The chosen spread — M7's generalization of M6's hard-coded three.
    /// Defaults to the M6 spread, so a cold launch is the same ritual it was.
    @State private var spread = Spread.threeCards

    /// The dealt reading — `spread.count` `DrawnCard`s, each with its fall (M5).
    @State private var reading: Reading?
    /// Which positions are face-up.
    @State private var revealed: Set<Int> = []
    /// The position whose meaning the panel shows — the last one tapped.
    @State private var focus: Int?
    /// Set while a debug hook (M6's, M7-extended) re-deals, so the picker's
    /// `onChange` doesn't deal a second, different reading over it.
    @State private var suppressReDeal = false

    /// A card that is up *and* whose scene is active: the holo/motion state.
    private var live: Bool { !revealed.isEmpty && scenePhase == .active }

    /// How many dealt cards the table shows — always `spread.count` once the
    /// (automatic) deal has happened; the `min` defends the one frame in
    /// which a spread switch and its re-deal might not have met yet.
    private var count: Int { min(spread.count, reading?.count ?? 0) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(spread.name)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 4)

                spreadPicker
                cardArea
                meaningPanel
                newReadingButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .onAppear {
            if reading == nil { deal() }     // the deal is automatic — the ritual starts on launch
            #if DEBUG
            applyDebugHook()
            #endif
        }
        .onChange(of: spread) { _, _ in
            if suppressReDeal { suppressReDeal = false; return }
            withAnimation(flip) { deal() }   // the new spread's cards, all face-down
        }
        .onChange(of: live) { _, isLive in
            tilt.setFaceUp(isLive)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: The spread picker

    private var spreadPicker: some View {
        Picker("Spread", selection: $spread) {
            ForEach(Spread.all) { s in
                Text(s.name).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Choose a spread")
    }

    // MARK: The cards

    /// The dealt cards, positioned by `SpreadLayout` in whatever space the
    /// table's chrome leaves. The area is flexible — it takes the leftover
    /// height, so *the cards* (and only the cards) shrink to make room for a
    /// revealed meaning: the cross re-scales from ten comfy backs to ten
    /// smaller ones as the panel grows, and never overflows.
    private var cardArea: some View {
        GeometryReader { geo in
            let frames = SpreadLayout.frames(for: spread,
                                            in: geo.size,
                                            bottomInset: spread.labelsUnderCards ? SpreadLayout.labelInset : 0)
            ForEach(0..<count, id: \.self) { i in
                let f = frames[i]
                let position = spread.positions[i]
                let isUp = revealed.contains(i)
                let drawn = reading?.draws[i]

                RevealCard(card: drawn?.card ?? deck[0],
                            faceUp: isUp,
                            reduceMotion: reduceMotion,
                            tilt: tilt,
                            isFaceUp: isUp && scenePhase == .active)
                    .frame(width: f.width, height: f.height)
                    // Generous hit target: the cross's ten can be under the
                    // 44 pt HIG floor at the smallest iPhone, so the tappable
                    // area extends a little past the card edge (the row gaps
                    // are wider than the extension, so targets never collide
                    // badly; the rotation turns it with the crossing card).
                    .contentShape(Rectangle().inset(by: -5))
                    .onTapGesture { tap(i) }
                    // One VoiceOver element per card (roadmap M6, held):
                    // position + name + fall, whether or not it is up.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label(i, drawn: drawn, isUp: isUp, position: position.name))
                    .accessibilityAddTraits(.isButton)
                    .rotationEffect(.degrees(position.rotation))
                    .position(x: f.midX, y: f.midY)

                if spread.labelsUnderCards {
                    Text(position.name)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(isUp ? 0.85 : 0.45))
                        .lineLimit(1)
                        .frame(maxWidth: f.width)
                        .contentShape(Rectangle().inset(by: -4))   // the label belongs to its card (M6 behavior)
                        .onTapGesture { tap(i) }
                        .position(x: f.midX, y: f.maxY + SpreadLayout.labelInset / 2)
                        .accessibilityHidden(true)   // the card's own label carries it
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func label(_ i: Int, drawn: DrawnCard?, isUp: Bool, position: String) -> String {
        guard isUp, let drawn else {
            return "\(position) card, face down. Double tap to reveal."
        }
        let fall = drawn.orientation == .inverted ? ", inverted" : ""
        return "\(position) card: \(drawn.card.name)\(fall), revealed. Double tap to show its meaning."
    }

    // MARK: The meaning panel

    @ViewBuilder
    private var meaningPanel: some View {
        if let f = focus, f < count, let drawn = reading?.draws[f] {
            let position = spread.positions[f]
            VStack(spacing: 8) {
                Text(position.name)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.45))
                Text(position.prompt)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
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
            .accessibilityLabel("\(position.name), \(position.prompt): \(drawn.card.name), \(drawn.orientation.label). \(drawn.meaning)")
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

    private var newReadingButton: some View {
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

    /// "New reading": deal the same spread fresh, all face-down. The
    /// revealed cards flip back over (the new art is hidden under the backs
    /// until flipped).
    private func newReading() {
        withAnimation(flip) { deal() }
    }

    private func deal() {
        // A fresh engine per deal (M5): the platform CSPRNG, one shuffle.
        // Not stored — a fresh CSPRNG is just as random, and keeping it local
        // keeps `deal()` non-mutating (it only touches `@State`), so it works
        // from `onAppear`, the picker, and the button alike. The free-tier
        // deck swap (M9) belongs in this one line.
        var engine = ReadingEngine()
        reading = engine.deal(count: spread.count, from: deck)
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
    /// Launch arguments for screenshot passes (the M6 hook, M7-extended):
    ///   `-augurySpread <id>`  — deal that spread: `one-card`, `three-card`,
    ///                           or `celtic-cross` (matches the picker)
    ///   `-auguryCard <slug>`  — force the first position to a known arcana
    ///                           (its assetName), so a worst-case card can be
    ///                           pinned, e.g. `-auguryCard the-high-priestess`
    ///   `-auguryRevealed`     — reveal every position (holo + meaning panel)
    ///   `-auguryInverted`     — force every card to fall inverted
    /// Value flags accept either `-flag value` or `-flag=value`.
    private func applyDebugHook() {
        if let raw = launchArg("-augurySpread"),
           let s = Spread.all.first(where: { $0.id == raw.lowercased().replacingOccurrences(of: " ", with: "-") || $0.name.lowercased() == raw.lowercased() }),
           s.id != spread.id {
            suppressReDeal = true    // the picker's onChange would deal a second time
            spread = s
            deal()
        }
        if let slug = launchArg("-auguryCard"), let r = reading {
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
            revealed = Set(0..<spread.count)
            focus = 0
        }
    }

    /// A `-auguryFoo value` or `-auguryFoo=value` launch argument.
    private func launchArg(_ flag: String) -> String? {
        if let i = CommandLine.arguments.firstIndex(where: { $0 == flag }),
           i + 1 < CommandLine.arguments.count {
            return CommandLine.arguments[i + 1]
        }
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix(flag + "=") }) {
            return String(arg.dropFirst(flag.count + 1))
        }
        return nil
    }
    #endif
}

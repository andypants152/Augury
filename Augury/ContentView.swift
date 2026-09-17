import SwiftUI

/// The table — one card at a time. Tap deals a random card face-down (the
/// card back); the next tap flips it over to reveal its line art **with the
/// holographic finish** — the one live layer. Tap a revealed card to deal
/// the next one. The full table / draw / flip / reveal for 3-card and
/// Celtic-cross readings lands in M6.
///
/// Each card's art ships as two layers in the asset catalog: the shared
/// `card-bg` gradient plus the card's transparent line-art layer, both
/// canonical SVGs that `actool` rasterizes at 3x (the sparse art layers keep
/// the whole deck around 8 MB in the compiled catalog instead of ~130 MB).
/// See `tools/card-draft` for how the deck is made.
struct ContentView: View {
    @StateObject private var tilt = MotionTilt()
    @State private var index = 0
    @State private var faceUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let cards = Arcana.all

    /// The card is revealed — the holo and CoreMotion are live. Scene-aware:
    /// backgrounded, nothing is revealed, so nothing draws.
    private var revealed: Bool { faceUp && scenePhase == .active }

    var body: some View {
        let card = cards[index]
        ZStack {
            Color.black.ignoresSafeArea()
            // The holo is applied to the card's *line layer* (inside
            // `CardFace`), not to the composited face — the dark ground must
            // stay still; only the ink shimmers. See `holoFinish`.
            RevealCard(card: card, faceUp: faceUp, reduceMotion: reduceMotion,
                        tilt: tilt, isFaceUp: revealed)
                .padding(12)
        }
        .contentShape(Rectangle())
        .onTapGesture { tap() }
        .onAppear {
            if !faceUp { deal() }          // the first card of the session
            #if DEBUG
            // Verification hook: `xcrun simctl launch ... --arguments -auguryCard
            // <slug> -auguryRevealed` starts on a known, revealed card so a
            // render pass can screenshot face-up state without a tap.
            if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("-auguryCard") }),
               arg.count > "-auguryCard=".count {
                let slug = String(arg.dropFirst("-auguryCard=".count))
                if let i = cards.firstIndex(where: { $0.assetName == slug }) {
                    index = i
                    if CommandLine.arguments.contains("-auguryRevealed") { faceUp = true }
                }
            }
            #endif
        }
        .onChange(of: revealed) { _, newValue in
            tilt.setFaceUp(newValue)
        }
        .accessibilityLabel(faceUp
            ? "\(card.name), tap to deal another card"
            : "Card back, tap to reveal")
    }

    private func tap() {
        if faceUp {
            deal()
        } else {
            reveal()
        }
    }

    /// Deal a random card face-down.
    private func deal() {
        var next = Int.random(in: cards.indices)
        if next == index { next = (next + 1) % cards.count }
        withAnimation(flipAnimation) {
            index = next
            faceUp = false
        }
    }

    /// Flip the dealt card over to reveal it.
    private func reveal() {
        withAnimation(flipAnimation) {
            faceUp = true
        }
    }

    /// Under Reduce Motion: a plain crossfade instead of a 3D flip
    /// (vestibular safety) — the holo is likewise frozen (see `HoloLayer`).
    private var flipAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.35) : .spring(response: 0.5, dampingFraction: 0.8)
    }
}

/// One card that can face either way: its face (`CardFace`) and the card
/// back, with a 3D flip between them. Under Reduce Motion, a crossfade
/// instead of rotation. `isFaceUp` is the scene-aware revealed state
/// (`faceUp && active`) — it gates the holo, which the front face carries.
struct RevealCard: View {
    let card: Arcana
    let faceUp: Bool
    let reduceMotion: Bool
    let tilt: MotionTilt
    let isFaceUp: Bool

    var body: some View {
        if reduceMotion {
            ZStack {
                CardBack()
                    .opacity(faceUp ? 0 : 1)
                CardFace(arcana: card, tilt: tilt, isFaceUp: isFaceUp)
                    .opacity(faceUp ? 1 : 0)
            }
        } else {
            FlipCard(angle: faceUp ? 0 : 180) {
                CardFace(arcana: card, tilt: tilt, isFaceUp: isFaceUp)
            } back: {
                CardBack()
            }
        }
    }
}

/// A two-sided card with a 3D flip. `angle` is animatable: 0 shows the
/// front, 180 the back. Each side is pre-rotated so exactly one side faces
/// the viewer, with a hard opacity swap at the 90° edge-on midpoint — no
/// mirrored bleed through the flip.
struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    private let front: () -> Front
    private let back: () -> Back

    init(angle: Double,
         @ViewBuilder front: @escaping () -> Front,
         @ViewBuilder back: @escaping () -> Back) {
        self.angle = angle
        self.front = front
        self.back = back
    }

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            front()
                .opacity(cos(angle * .pi / 180) > 0 ? 1 : 0)
                .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            back()
                .opacity(cos(angle * .pi / 180) < 0 ? 1 : 0)
                .rotation3DEffect(.degrees(angle + 180), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        }
    }
}

/// The card back — what a dealt card shows before the reveal: the shared
/// `card-bg` with the back's line-art layer on top (the same two-layer
/// compositing as `CardFace`).
struct CardBack: View {
    var body: some View {
        Image("card-bg")
            .resizable()
            .aspectRatio(CardFace.cardRatio, contentMode: .fit)
            .overlay(
                Image("card-back")
                    .resizable()
            )
    }
}

/// One face-up card: the shared `card-bg` with this card's line-art layer on top.
///
/// The art is an `.overlay` of the background (not a `ZStack` of two resizable
/// images): an overlay is proposed the exact size of the view it modifies, so
/// the two layers are always the same size and aligned. The 9:16 ratio is applied
/// to the background image itself — applying it to a `ZStack` of two fully-
/// flexible `.resizable()` images is ambiguous and distorts the card.
///
/// The holo finish is attached to the **art layer only**, here: the shader
/// gates on pixel alpha, so the sheen rides the ink (frame, starfield,
/// nameplate, figure) and the shared background stays perfectly still.
struct CardFace: View {
    let arcana: Arcana
    let tilt: MotionTilt
    /// The scene-aware revealed state — gates the holo (pairs with
    /// `MotionTilt.setFaceUp` for the CoreMotion start/stop).
    let isFaceUp: Bool

    static let cardRatio = 540.0 / 960.0   // the draft canvas, 9:16

    var body: some View {
        Image("card-bg")
            .resizable()
            .aspectRatio(Self.cardRatio, contentMode: .fit)
            .overlay(
                Image(arcana.assetName)
                    .resizable()
                    .holoFinish(tilt, isFaceUp: isFaceUp)
            )
    }
}

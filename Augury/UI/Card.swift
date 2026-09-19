import SwiftUI

/// One card that can face either way: its face (`CardFace`) and the card
/// back, with a 3D flip between them. Under Reduce Motion, a crossfade
/// instead of rotation. `isFaceUp` is the scene-aware revealed state
/// (`faceUp && active`) — it gates the holo, which the front face carries.
///
/// The card's **fall** (`orientation`) is how it rests once revealed: an
/// inverted card shows its art a half-turn from upright — the *face*
/// rotates, the back never does (a fall is a property of the face, and the
/// backs of a real deck stay uniform).
struct RevealCard: View {
    let card: Arcana
    /// How the card fell — the revealed face is rotated to match.
    let orientation: Orientation
    let faceUp: Bool
    let reduceMotion: Bool
    let tilt: MotionTilt
    let isFaceUp: Bool

    var body: some View {
        if reduceMotion {
            ZStack {
                CardBack()
                    .opacity(faceUp ? 0 : 1)
                CardFace(arcana: card, orientation: orientation, tilt: tilt, isFaceUp: isFaceUp)
                    .opacity(faceUp ? 1 : 0)
            }
        } else {
            FlipCard(angle: faceUp ? 0 : 180) {
                CardFace(arcana: card, orientation: orientation, tilt: tilt, isFaceUp: isFaceUp)
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

/// One face-up card: the shared `card-bg` with this card's line-art layer on
/// top, rotated to show how it fell (upright as authored, inverted a
/// half-turn).
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
///
/// **The fall rotates the *whole face*, and it is the last step** — applied
/// after `holoFinish`: the shader picks its foil zone from the art layer's
/// own pixels (frame → gold, nameplate → silver, subject + starfield →
/// rainbow), so a rotation applied *before* the effect would move the ink
/// out from under its zone. Rotated after it, every zone keeps its foil, and
/// the sheen rides the turned card the way foil on a real reversed card
/// would. (The shared background is a radial glow — turning it with the art
/// is not perceptible, and it belongs to the front of the card, so it
/// turns.)
struct CardFace: View {
    let arcana: Arcana
    /// How the card fell — the face is rotated a half-turn when inverted.
    let orientation: Orientation
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
            // The fall: an inverted card lies a half-turn from upright —
            // figure, starfield, frame, and nameplate together, the way a
            // physical reversed card rests. *Outside* the holo: the shader's
            // zones live in the art layer's own space (see above).
            .rotationEffect(.degrees(orientation.rotation))
    }
}

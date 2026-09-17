import SwiftUI

/// The holographic foil finish — Augury's **one live rendering layer**.
///
/// Applied to the revealed card's **line layer** (the transparent art layer in
/// `CardFace`), it gives the ink a shimmer that shifts with the viewing angle.
/// The shader gates on pixel alpha (only ink shimmers; the shared `card-bg` is a
/// sibling view this never touches, so the dark ground stays still) and picks a
/// **different foil palette per zone** of the card:
///
///   • the **frame** (gold border + corner stars)  → shimmering gold
///   • the **nameplate** (the name at the bottom)  → shimmering silver
///   • the **subject + starfield** (the rest)     → holo-foil rainbow
///
/// **Do not attach this to the composited card:** the ground would shimmer too,
/// and the whole face reads as noise.
///
/// The made-once-done promise holds: the card's identity is the committed SVG;
/// the holo is a transient material that reacts to light/angle (roadmap M4).
///
/// Drive sources, in priority order (see `angle`):
/// 1. **Reduce Motion** → a fixed angle and frozen time: a static sheen, no shimmer.
/// 2. **Live tilt** (`MotionTilt.isLive`) → the device attitude sweeps the foil.
/// 3. **Time-based shimmer** (simulator / sensor-less) → a slow organic drift.
///
/// The `TimelineView` is **paused** whenever the card is not revealed, so the
/// shader does zero work when nothing is face-up (no idle draw).
struct HoloLayer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Clock origin — `@State` so it survives view re-inits; the sheen's time
    /// drift never resets when SwiftUI rebuilds this modifier.
    @State private var start = Date()

    let tilt: MotionTilt
    var isFaceUp: Bool
    /// Overall sheen strength. Kept low on purpose — "a whisper, not a strobe".
    var intensity: Double = 0.45

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion || !isFaceUp)) { timeline in
            // Time since this card appeared, not since the reference date: the
            // shader takes a float32, which cannot represent 7.8e8 seconds with
            // sub-frame precision (that quantizes the drift to ~64-second
            // jumps). Seconds-since-appearance stays precise for hours.
            let t = reduceMotion
                ? Self.frozenTime
                : timeline.date.timeIntervalSince(start)
            let a = Self.angle(reduceMotion: reduceMotion,
                               isLive: tilt.isLive,
                               liveAngle: tilt.angle,
                               t: t)
            // The shader maps `position` → canvas units (540×960) to pick the
            // foil zone, so it needs the layer's rendered size (same units as
            // `position`). A GeometryReader reads it without affecting layout:
            // the art layer fills the proposed (card) size either way.
            GeometryReader { geo in
                content
                    .colorEffect(
                        ShaderLibrary.default.holo(
                            .float2(Float(a.dx), Float(a.dy)),
                            .float(Float(t)),
                            .float(Float(intensity)),
                            .float(isFaceUp ? 1 : 0),
                            .float2(Float(geo.size.width), Float(geo.size.height))
                        )
                    )
            }
        }
    }

    // MARK: Angle resolution — the holo rules in one testable place (roadmap M4).

    /// The fixed sheen angle under Reduce Motion: present, but frozen — no shimmer.
    static let fixedAngle = CGVector(dx: 0.35, dy: -0.2)

    /// A frozen clock under Reduce Motion: a constant, so the sheen never drifts.
    static let frozenTime: Double = 12.0

    /// The drive source, in priority order:
    /// 1. Reduce Motion → the fixed angle (the `time` parameter is frozen separately).
    /// 2. Live tilt (a sensor is present) → the device attitude sweeps the foil.
    /// 3. Otherwise → a slow time-based shimmer (simulator / sensor-less).
    static func angle(reduceMotion: Bool, isLive: Bool, liveAngle: CGVector, t: Double) -> CGVector {
        if reduceMotion { return fixedAngle }
        if isLive { return liveAngle }
        return shimmer(t)
    }

    /// The no-sensor fallback: a slow, asymmetric drift so the foil still feels
    /// alive (the two Lissajous frequencies are incommensurate → no visible
    /// repeat). Amplitudes are small — the drift, not the bands, is the motion.
    static func shimmer(_ t: Double) -> CGVector {
        CGVector(dx: 0.4 * sin(t * 0.30),
                 dy: 0.4 * cos(t * 0.23 + 1.1))
    }
}

extension View {
    /// Apply the holographic foil. **Attach to the card's transparent line
    /// layer, not the composited face** — the sheen rides the ink and the
    /// background must stay still (the shader gates on pixel alpha). The foil
    /// takes gold on the frame, silver on the nameplate, and holo-foil rainbow
    /// on the subject and starfield. `isFaceUp` gates the effect and pairs with
    /// `MotionTilt.setFaceUp` for the CoreMotion start/stop.
    func holoFinish(_ tilt: MotionTilt, isFaceUp: Bool, intensity: Double = 0.45) -> some View {
        modifier(HoloLayer(tilt: tilt, isFaceUp: isFaceUp, intensity: intensity))
    }
}

#include <metal_stdlib>
using namespace metal;

// HoloFinish — the one live layer in Augury.
//
// An iridescent foil that **rides the line art only** and takes a *different
// palette per zone* of the card (roadmap M4):
//
//   • the **frame** (the gold border + its corner stars)   → shimmering gold
//   • the **nameplate** (the name at the bottom)          → shimmering silver
//   • the **subject + starfield** (everything else)       → holo-foil rainbow
//
// The card is two sibling views: the shared opaque `card-bg` (this shader never
// sees it — the dark ground stays perfectly still) and the transparent line
// layer, on which `colorEffect` applies this. The shader gates on pixel alpha
// (only ink shimmers) and picks the palette from the pixel's canvas position,
// so the border, the name, and the figure each shimmer in their own metal.
//
// Model: thin-film interference — a diagonal band field whose phase depends on
// (a) surface position, (b) the viewing angle from device tilt, and (c) a slow
// time drift. Tilt rotates/rescales the bands so the foil sweeps; the drift
// keeps it alive when the phone is still. Subtle by design — "a whisper, not a
// strobe" (roadmap M4/M11).
//
// Applied via SwiftUI `colorEffect`: `position` (user-space points) and `color`
// (the line layer's pixel) are injected; `viewAngle`, `time`, `intensity`,
// `enabled`, and `size` (the layer's rendered size, in the same units as
// `position`) are supplied from Swift.

// ── zone detection ───────────────────────────────────────────────────────────
// Canvas is 540×960 (the draft canvas). Zones are expressed in canvas units so
// they are resolution-independent. The scaffolding geometry is fixed across all
// 78 cards (see generate.py `frame()` / `nameplate()`), so these constants are
// stable: gold frame border at inset 16 (stroke 2.4), its corner stars at inset
// ~52, the nameplate baseline at y = H−66 centered on x = W/2.
#define CANVAS_W 540.0
#define CANVAS_H 960.0

// 0 = frame (gold), 1 = nameplate (silver), 2 = subject + starfield (rainbow).
static inline int zoneOf(float2 p) {
    // Frame: the border band (inset 10..32) hugs the gold frame at inset 16
    // *and* captures the faint inner hairline at inset 30, so the whole frame
    // system shimmers as one gold element. Plus the four corner boxes (inset
    // 32..70) that catch the gold corner stars.
    bool band   = (p.x < 32.0 || p.x > CANVAS_W - 32.0 ||
                   p.y < 32.0 || p.y > CANVAS_H - 32.0)
               && (p.x > 10.0 && p.x < CANVAS_W - 10.0 &&
                   p.y > 10.0 && p.y < CANVAS_H - 10.0);
    bool corner = (p.x > 32.0 && p.x < 70.0 && p.y > 32.0 && p.y < 70.0)
               || (p.x > CANVAS_W - 70.0 && p.x < CANVAS_W - 32.0 && p.y > 32.0 && p.y < 70.0)
               || (p.x > 32.0 && p.x < 70.0 && p.y > CANVAS_H - 70.0 && p.y < CANVAS_H - 32.0)
               || (p.x > CANVAS_W - 70.0 && p.x > 0.0 && p.x < CANVAS_W - 32.0 && p.y > CANVAS_H - 70.0 && p.y < CANVAS_H - 32.0);
    if (band || corner) { return 0; }

    // Nameplate: a box around the centered name (baseline y = H−66 = 894; the
    // glyphs sit just above it). Wide enough for the longest name, narrow enough
    // to stay clear of the bottom border and the corner stars.
    if (p.x > 110.0 && p.x < CANVAS_W - 110.0 &&
        p.y > 868.0 && p.y < 900.0) { return 1; }

    return 2;   // the subject figure + the scattered starfield
}

// ── palettes ──────────────────────────────────────────────────────────────────
// Each returns the *target* foil color at the crest of a band, at roughly the
// ink's luminance so it reads on the bright line art. Gold and silver are fixed
// metals — their shimmer is a light sweep, not a hue cycle. The rainbow cycles
// hue with `t` (it must, to read as iridescent).

// Shimmering gold (the frame).
static inline half3 goldFoil() {
    return half3(1.00, 0.80, 0.45);
}

// Shimmering silver (the nameplate).
static inline half3 silverFoil() {
    return half3(0.90, 0.93, 1.00);
}

// Holo-foil rainbow (the subject + starfield). A smooth cyclic rainbow (Quilez
// cosine palette), lifted to the ink's luminance. Tuned cool: cyan → violet →
// magenta → gold. `t` need not be 0..1.
static inline half3 holoFoil(float t) {
    const float3 a = float3(0.50, 0.50, 0.50);
    const float3 b = float3(0.50, 0.50, 0.50);
    const float3 c = float3(1.00, 1.00, 1.00);
    const float3 d = float3(0.00, 0.33, 0.67);
    return min(half3(a + b * cos(6.28318530718 * (c * t + d))) * 1.7, half3(1.0));
}

[[stitchable]] half4 holo(float2 position, half4 color,
                          float2 viewAngle,   // radians (roll, pitch) from device tilt
                          float  time,        // seconds; a constant under Reduce Motion
                          float  intensity,   // overall strength — keep low
                          float  enabled,     // 1 = face-up, 0 = face-down / paused
                          float2 size)        // the layer's rendered size (≈ position units)
{
    if (enabled < 0.5) { return color; }

    // The line layer is transparent everywhere except the ink. Clean ground
    // pixels pass through untouched; anti-aliased edges scale with alpha.
    half a = color.a;
    if (a < half(1.0 / 255.0)) { return color; }

    // Canvas-space position (0..540, 0..960) for zone detection. `position` and
    // `size` are in the same units, so the ratio is unit-free.
    float2 p = position * (float2(CANVAS_W, CANVAS_H) / size);

    // Diagonal band field. The viewing angle rotates and rescales the bands so
    // tilting the phone sweeps the foil; `time` adds a slow drift. (Kept in
    // `position` space so the band scale matches the approved look.)
    float phase = position.x * (0.9 + 0.6 * sin(viewAngle.x))
                + position.y * (0.9 + 0.6 * cos(viewAngle.y))
                + time * 0.35;

    // Interference fringes, sharpened into soft bands (0..1).
    half bands = half(pow(sin(phase * 0.045) * 0.5 + 0.5, 2.2));

    // The zone picks the foil palette — and how hard it pushes. Gold and the
    // rainbow are close to the ink's own hue, so a light wash; the nameplate's
    // base ink is *gold*, so the silver needs a harder push to actually land on
    // silver (the name shimmers gold → silver along the band).
    int zone = zoneOf(p);
    half3 foil;
    half push;
    if (zone == 0)       { foil = goldFoil();               push = 1.0; }
    else if (zone == 1)  { foil = silverFoil();             push = 1.8; }
    else                 { foil = holoFoil(phase * 0.018);  push = 1.0; }

    // The shimmer: the ink swells bright on the crest of a band, dims in the
    // trough, and washes toward the zone's foil color at the crest — a foil
    // stamp on the lines, not a flood over the card. Kept low on purpose so the
    // default reads as a whisper, not a strobe.
    half k = half(intensity);
    half brightness = 1.0 + (bands - 0.5) * 1.6 * k;   // 1 ± 0.8·intensity
    half3 out = mix(color.rgb * brightness, foil, min(bands * k * push, half(1.0)));
    return half4(out, color.a);
}

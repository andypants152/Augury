# Augury

A tarot / oracle reading app you own. A complete, hand-made deck of **78 celestial
line-art cards** with a **holographic foil finish that shifts as you tilt the device**.

**One price ($9.99), yours forever. No subscription. No account. No internet.**

> **Status: M2** — the 78-card `Arcana` content model, plus the draft generator and the
> 78 first-pass **celestial line-art SVGs** in `drafts/`. The plan lives in [`roadmap.md`](roadmap.md).

The promise (short form): the deck is **made once, done** — 78 cards authored once and
committed as static SVGs, never changing. Canonical tarot meaning (upright + inverted).
The holographic finish is the one live layer — a foil that reacts to the light, not new
content.

## Build

```sh
brew install xcodegen   # one time
xcodegen generate
open Augury.xcodeproj
```

Or run the tests from the command line:

```sh
xcodegen generate
xcodebuild -project Augury.xcodeproj -scheme Augury \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Requires Xcode with the iOS Simulator (built against Xcode 26, iOS 17 deployment target,
Swift 5 language mode).

## Layout

- `Augury/` — the app target
  - `Models/Arcana.swift` — the `Arcana` / `ArcanaID` / `Suit` types
  - `Models/ArcanaCatalog.swift` — the 78 cards (names, keywords, upright + inverted meanings)
  - `AuguryApp.swift` / `ContentView.swift` — the app shell (grown in later milestones)
- `AuguryTests/` — unit tests
- `drafts/` — the 78 first-pass line-art SVGs (M2) + deck order; refined in M3, then committed to the bundle
- `tools/card-draft/` — the design-time pipeline (never shipped): `generate.py` (specs → SVGs) and `montage.swift` (contact-sheet previews at 3 sizes)
- `project.yml` — XcodeGen source of truth (the `.xcodeproj` is generated, not committed)
- `roadmap.md` — the plan (milestones, sharp edges, metrics)

## The promise

- **Made once, done.** The 78 cards are authored once and committed as static SVGs; the
  deck is permanent. No runtime generation, no daily content, no rotation.
- **Canonical meaning.** The traditional 78, each with real upright + inverted meanings.
- **Tactile, ritual feel.** The holo finish + deliberate pacing make a reading feel like
  handling a physical card. Calm, dark, quiet.
- **Offline, no account.** No network beyond StoreKit. The deck ships in the bundle;
  your reading journal lives on the device.
- **Pay once.** $9.99 non-consumable, one honest unlock.

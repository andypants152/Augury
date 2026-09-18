# Augury

A tarot / oracle reading app you own. A complete, hand-made deck of **78 celestial
line-art cards** with a **holographic foil finish that shifts as you tilt the device**.

**One price ($9.99), yours forever. No subscription. No account. No internet.**

> **Status: M7** — the 78-card deck **in the app bundle** (M1–M3), the
> holographic finish (M4), the deal engine (M5), and the spread-driven
> reading table (M6–M7): choose one card, three (past/present/future), or
> the Celtic cross — cards dealt face-down, flipped one at a time to reveal
> each under the holo, upright or inverted meaning included. The plan lives
> in [`roadmap.md`](roadmap.md).

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
  - `Models/Spread.swift` — the spreads: 1-card, 3-card, Celtic cross (names + prompts + layout, in deal order)
  - `Assets.xcassets` — the card art: a shared `card-bg` + one line-art layer per card (SVG sources, rasterized by `actool`)
  - `Engine/` — `HoloFinish` + `MotionTilt` (the holo, M4) and `Reading` (M5: the shuffle + deal + fall — the one real random)
  - `UI/` — the spread-driven reading table (M6–M7): the card components + `SpreadLayout` (fits any spread to the space) + the table itself — one card, three, or the Celtic cross
  - `AuguryApp.swift` / `ContentView.swift` — the app root (hosts the table)
- `AuguryTests/` — unit tests
- `drafts/` — the 78 canonical line-art SVGs (the committed source of truth; refined in M3) + deck order. `layers/` (gitignored) is the derived two-layer split; `_contact-sheet*.png` are review artifacts
- `tools/card-draft/` — the design-time pipeline (never shipped): `generate.py` (specs → SVGs + layer split), `montage.swift` (contact-sheet previews), `sync_assets.py` (layers → asset catalog, with validation)
- `project.yml` — XcodeGen source of truth (the `.xcodeproj` is generated, not committed)
- `roadmap.md` — the plan (milestones, sharp edges, metrics)

## The promise

- **Made once, done.** The 78 cards are authored once and committed as static SVGs; the
  deck is permanent. No runtime generation, no daily content, no rotation.
- **Canonical meaning.** The traditional 78, each with real upright + inverted meanings.
- **Tactile, ritual feel.** The holo finish + deliberate pacing make a reading feel like
  handling a physical card. Calm, dark, quiet.
- **Offline, no account.** No network beyond StoreKit. The deck ships in the bundle;
  your daily journal lives on the device.
- **Pay once.** $9.99 non-consumable, one honest unlock.

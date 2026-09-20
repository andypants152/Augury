# AGENTS.md — Augury

Orientation guide for AI agents (and humans) working in this repo. It compresses the
project structure and the load-bearing rules into one file so a fresh session can get
to work quickly. For the *plan* read `roadmap.md`; for the *product* read `README.md`.

## What Augury is

An iOS **SwiftUI tarot / oracle reading app you own**:

- A hand-made deck of **78 celestial line-art cards**, authored once and committed as
  static SVGs — **"made once, done"**. No runtime art generation, no daily content, no
  rotation. The deck is permanent.
- The **one live rendering layer** is a **holographic foil finish** (a Metal shader
  driven by device tilt) applied to revealed cards — a *finish, not content*.
- **A daily journal** (M8): a three-card reading saved as today's date-stamped
  entry; past days reopen — cards, meanings, note — append-only, local JSON.
  The app's only growing state.
- One price ($0.99), yours forever. Fully offline, no account, no backend.

**Current status: M9 complete.** M3 committed the rework of all 78 (the `Arcana`
model, the draft pipeline, and the full deck in the app bundle — two-layer SVGs,
`actool`-rasterized, ~8 MB — render-verified). M4 adds the holographic finish, the
one live layer: `Engine/HoloFinish.metal` (foil on the line layer only — gold frame,
silver nameplate, holo-foil rainbow on subject + starfield) + `Engine/MotionTilt.swift`
(attitude-only, time-shimmer fallback, Reduce-Motion-safe). M5 adds the deal engine,
`Engine/Reading.swift`: `ReadingEngine` is the one real "random" in the app — a single
`RandomNumberGenerator` (the platform CSPRNG in the app, a seeded splitmix64 in tests)
drives a Fisher–Yates shuffle, the deal, and each card's upright/inverted fall. M6
adds the table, `UI/ReadingTable.swift`: the three (past/present/future) dealt
face-down on launch, one tap flips a card over under the holo, its (upright or
inverted) meaning in the panel, "New reading" re-deals — the M4 one-card shell is
retired (its card components moved to `UI/Card.swift` unchanged). M7 makes the table
**spread-driven**: `Models/Spread.swift` (the 1-card, the 3-card, the Celtic cross —
named, prompted positions in deal order) + `UI/SpreadLayout.swift` (pure layout:
scale the spec to fit, rotation-aware — the cross's crossing card lies at 90° over
the present); a picker chooses the spread, the deal still flows through the M5 engine,
and the cross's ten face-down fit the smallest iPhone (pinned in
`AuguryTests/SpreadTests.swift`). M8 adds the **daily journal**:
`Store/ReadingStore.swift` (one entry per day — a same-day re-save updates in
place, keeping the day's stamp and the user's note; append-only, local JSON,
uncapped — the free-tier cap is the M9 entitlement, above it) + `UI/JournalView.swift`
(the day list, newest first; a day reopened flips its three up under the holo
with an editable note). M9 adds **free/paid gating**:
`Store/PurchaseManager.swift` (`Entitlement` — free / full — is the single
value the app consults at three points: which deck the engine shuffles from,
which spreads the picker offers, and how many journal entries the journal
presents; the store stays uncapped below it) + `UI/Paywall.swift` (the
one-time unlock, $0.99 — the price stated plainly) — one non-consumable lifts
everything at once; the purchase *result* is never the grant,
`currentEntitlements` is, and a verify never downgrades.
The root (`ContentView`) owns the one store and the one `PurchaseManager`,
and swaps the two rooms — table / journal — by opacity, so a trip to the
journal never loses the table's deal, and a hidden table pauses the holo (no
idle draw). The 1.0 **bonus** (unnumbered; landed between M9 and M10) adds the
two Siri / Shortcuts actions (`Intents/AuguryIntents.swift`, routed through
`Engine/SiriNavigation`) and the **private, on-device reflection**
(`Engine/ReadingInterpreter` + `UI/ReadingReflectionView`) — Foundation
Models (Apple Intelligence, iOS 26+): a fresh, stateless session on a
*completed* spread, in a sheet that pauses the holo like any modal. The model
only comments on the deal — it never chooses cards, falls, or meanings.
`roadmap.md` ("Where we are") is the canonical plan.

## Repo layout

```
Augury/
├── AGENTS.md               ← this file
├── README.md               product pitch + build instructions
├── roadmap.md              ← the plan: milestones M1–M12, design principles, sharp edges
├── project.yml             ← source of truth for the Xcode project (XcodeGen)
├── Augury.xcodeproj/       GENERATED from project.yml — gitignored, never hand-edit
├── Augury/                 the app target
│   ├── Assets.xcassets/    the card art (see "Card art pipeline")
│   │   ├── card-bg.imageset    ONE shared background (radial indigo glow, stored once)
│   │   ├── card-back.imageset  the card back
│   │   └── <name>.imageset/    78 line-art layers, one per card (SVG source + Contents.json)
│   ├── AuguryApp.swift     @main entry (registers the Siri / Shortcuts phrases)
│   ├── ContentView.swift   root: owns the one `ReadingStore` +
│   │                       `PurchaseManager`; hosts the two rooms (the table /
│   │                       the journal), opacity-swapped; routes Siri requests
│   ├── Models/
│   │   ├── Arcana.swift        Suit / ArcanaID (78 cases) / Arcana types + assetName mapping
│   │   ├── ArcanaCatalog.swift the 78 cards: names, keywords, upright + inverted meanings
│   │   └── Spread.swift        the spreads (M7): 1-card / 3-card / Celtic cross —
│   │                           named + prompted positions in deal order, layout in card units
│   ├── Engine/
│       ├── HoloFinish.metal  Metal shader: the iridescent foil ("the one live layer")
│       ├── HoloLayer.swift   SwiftUI ViewModifier applying the shader (TimelineView + colorEffect)
│       ├── MotionTilt.swift  CMMotionManager attitude tracking (no permission needed)
│       ├── Reading.swift     M5 deal: Orientation / DrawnCard / Reading / SeededRNG /
│       │                     ReadingEngine — the one real "random" in the app
│       ├── ReadingInterpreter.swift  1.0 bonus: the private, on-device reflection
│       │                           (Foundation Models, Apple Intelligence, iOS 26+)
│       │                           — commentary on a completed spread, never the deal
│       └── SiriNavigation.swift     1.0 bonus: the App-Intent → root handoff channel
│                                     (pending default for the cold launch; a
│                                     notification for the running app)
│   ├── Intents/
│       └── AuguryIntents.swift  1.0 bonus: the two Siri / Shortcuts actions
│                                 ("Start a tarot reading", "Open the tarot journal")
│   ├── Store/
│   │   ├── ReadingStore.swift M8 journal: `JournalEntry` / `ReadingStore` — one per
│   │   │                       day (upsert, stamp + note preserved), local JSON,
│   │   │                       atomic writes, corrupt-file quarantine, uncapped (the
│   │   │                       free-tier cap is the M9 entitlement, above it)
│   │   └── PurchaseManager.swift M9: `Entitlement` (free/full — the single gate:
│   │       the deck, the spreads, the journal cap) + `PurchaseManager` (StoreKit 2
│   │       behind a `StoreKitClient` seam; the purchase result is never the grant —
│   │       `currentEntitlements` is, and a verify never downgrades)
│   └── UI/
│       ├── Card.swift        RevealCard / FlipCard / CardFace / CardBack — the card
│       │                     components (overlay-composited, holo on the art layer)
│       ├── SpreadLayout.swift M7 pure layout: card-unit spec → rotation-aware bounds →
│       │                       scale-to-fit + center (the cross's 90° crossing card included)
│       ├── ReadingTable.swift M6/M7 table: spread picker, dealt face-down, tap to flip +
│       │                       reveal under the holo, meaning panel, new reading, the M8
│       │                       save row + journal button; M9: the deal + picker follow
│       │                       the entitlement, the save row knows the cap; 1.0 bonus:
│       │                       the "Reading" button (a complete spread) + the
│       │                       reflection sheet; a Siri request re-deals fresh
│       ├── JournalView.swift  M8 journal: the day list (newest first) + a day reopened —
│       │                       cards flip up under the holo, note field; rows use a
│       │                       motion source that is never started; M9 presents the
│       │                       tier-visible entries (3 or all) + the one unlock row
│       ├── Paywall.swift M9: the full-screen paywall — the one-time price stated
│       │                     plainly (store `displayPrice`, or the documented $0.99
│       │                     until it loads) + the three unlocks + restore
│       └── ReadingReflectionView.swift 1.0 bonus: the reflection sheet — the
│                               model's output above the table (medium/large
│                               detent; pauses the holo like any modal)
├── AuguryTests/
│   ├── ArcanaTests.swift     78/78 cards, non-empty fields, 156 meanings, 22/56 split, 14/suit
│   ├── CardArtTests.swift    regression: assetName ↔ draft filename mapping
│   ├── ReadingTests.swift    M5: 1,000-deal fairness (distinct, no lucky card, 50/50
│   │                         falls), seed replay, full-deck permutation
│   ├── SpreadTests.swift     M7: spread catalog, canonical cross order, distinct deals,
│   │                         no overflow on the smallest iPhone, only-the-crossing overlap
│   ├── ReadingStoreTests.swift M8: one-per-day upsert (stamp + note preserved),
│   │                             kill+relaunch identity, note mutation, corrupt-file
│   │                             quarantine, uncapped
│   ├── PurchaseManagerTests.swift M9: the entitlement's three gates (free = majors,
│                                     2 spreads, cap 3; full lifts all) + the manager
│                                     through a fake `StoreKitClient` (one purchase
│                                     lifts everything; verify never downgrades;
│                                     price fallback)
│   ├── ReadingInterpreterTests.swift 1.0 bonus: the prompt's shape — the completed
│   │                                   spread + the grounding preamble, nothing else
│   └── SiriNavigationTests.swift 1.0 bonus: the cold-launch pending channel
├── drafts/                 ← the source of truth for the ART (committed)
│   ├── _order.txt              deck order (22 majors, then wands/cups/swords/pentacles)
│   ├── card-back.svg
│   ├── <name>.svg              the 78 full-card SVGs, 540×960 (background + art)
│   ├── layers/                 derived two-layer split — gitignored, regenerable
│   └── _contact-sheet*.png     review artifacts — gitignored
├── tools/card-draft/       the design-time pipeline (never shipped)
│   ├── generate.py     specs → 78 SVGs + layer split (deterministic, seeded)
│   ├── montage.swift   SVGs → contact-sheet PNGs (presets s|m|l|all)
│   └── sync_assets.py  layers → Assets.xcassets (validates; non-zero exit on bad files)
├── build/                  local Xcode output — gitignored
└── .scratch/               throwaway local review workspace — gitignored, never commit
```

## Build & test

No SPM dependencies — pure SwiftUI + Metal + CoreMotion, + Foundation Models
(the 1.0 bonus's reflection). Xcode 27, iOS 17.0 deployment target, Swift 5
language mode, portrait-only iPhone, bundle id `xyz.andypants.augury`. The
reflection imports the Foundation Models SDK, so **building needs Xcode 26+**;
at runtime the feature is gated to iOS 26 devices (everything else runs from
iOS 17).

```sh
brew install xcodegen            # one time
xcodegen generate               # (re)generate Augury.xcodeproj from project.yml
open Augury.xcodeproj

# all unit tests, from the repo root
xcodebuild -project Augury.xcodeproj -scheme Augury \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

**Always `xcodegen generate` after editing `project.yml`** — the committed source of
truth is the YAML, the `.xcodeproj` is a generated artifact.

## The card art pipeline

How a card travels from idea to app bundle:

1. **Spec** — per-arcana celestial specs live *in code* in `tools/card-draft/generate.py`
   (motif, palette, composition rules).
2. **Draft** — `python3 tools/card-draft/generate.py [--out drafts] [--seed 1]`
   writes the 78 full SVGs into `drafts/`, the two-layer split into `drafts/layers/`
   (gitignored), and `_order.txt`. It is **deterministic** (seeded per card): same run
   → byte-identical output, and it validates the XML.
3. **Refine** — a **one-by-one** pass: take the next card and ask *does it read as
   this arcana? does the suit read as its suit? is the line style consistent?* The
   main lever is the per-arcana figure/spec code in `generate.py` — add or adjust
   primitives (the current pass introduced `wand()`, `blade()`, `pentacle()`,
   `starpath()`, and reworked `pillars()` so each suit's motif is unmistakable);
   hand-editing `drafts/*.svg` is for one-offs that shouldn't generalize. Verify
   the card in the app (or via the `.scratch` render loop) before moving to the next;
   the rework accumulates in the working tree and is committed in chunks.
4. **Sync** — `python3 tools/card-draft/sync_assets.py drafts/layers Augury/Assets.xcassets`
   rewrites each `.imageset` from the layer SVGs. Exits non-zero on validation failure,
   so a bad draft can never sneak into the bundle.
5. **Review** — `swift tools/card-draft/montage.swift drafts` rasterizes the deck into
   contact sheets (staged: 22 majors, then 56 minors) for eyeballing the whole deck at once.
6. **Verify** — build + render-verify in-app (frame, starfield, and nameplate present per card).

The **two-layer design is load-bearing**: the shared `card-bg` (radial indigo glow) is
stored **once** for all 79 faces; each card ships only its **transparent line-art
layer**. `actool` rasterizes the SVGs at 3x at build time; the sparse art layers keep
the compiled catalog at **~8 MB** — a single full-card raster per card would be ~130 MB.

## Invariants & sharp edges

These are the things that silently break or violate the product's promises.

- **Asset-name mapping must match the draft filename exactly**, or the card renders as a
  bare background. `Arcana.assetName`: majors derive from the *display name* — six of
  the 22 (Strength, Wheel of Fortune, Justice, Death, Temperance, Judgement) take no
  "The" and must **not** get a `the-` prefix; minors are `suit-rank` (`wandsAce` →
  `wands-ace`). Regression-tested in `AuguryTests/CardArtTests.swift` — keep it green.
- **Composite with `.overlay`, not `ZStack`.** `CardFace` overlays the art layer on the
  background image: an overlay is proposed the exact size of the view it modifies, so
  the layers always align. A `ZStack` of two fully-flexible `.resizable()` images is
  ambiguous and distorts the card. The 9:16 ratio (`540/960`) is applied to the
  *background image* itself.
- **The fall rotates the *face* — never the back, and never before the holo.**
  An inverted card renders its whole face a half-turn (`Orientation.rotation`,
  applied in `CardFace` as a `rotationEffect` on the *composited* face — figure,
  starfield, frame, and nameplate turn together, the way a physical reversed card
  rests). The rotation sits **after** `holoFinish`: the shader's zones (frame →
  gold, nameplate → silver, subject → rainbow) are anchored in the art layer's own
  pixel space, so a rotation before the effect would move the ink out from under its
  foil. The card *back* is never rotated (a fall is a property of the face; the
  backs of a real deck stay uniform, so a face-down card must not hint at it).
- **The deck is made once, done.** Never add runtime art generation, daily content, or
  rotation. If a requirement seems to need "cards that change", push back — the one
  sanctioned live layer is the holo finish. (Runtime generation is parked as a v2 *opt-in*,
  off the critical path — see roadmap.md.)
- **Holo rules** (M4): subtle — "a whisper, not a strobe" (low intensity); the
  `TimelineView` is paused and `MotionTilt` stops whenever no card is face-up (no idle
  draw / battery drain); **Reduce Motion** → fixed angle, frozen time; no sensor
  (simulator) → smooth time-based shimmer. **The sheen rides the line layer only** —
  `holoFinish` attaches to the transparent art layer in `CardFace`, and the shader gates
  on pixel alpha and picks a foil **per zone**: frame → gold, nameplate → silver,
  subject + starfield → holo-foil rainbow; the shared `card-bg` stays perfectly still.
  The zone geometry in `HoloFinish.metal` mirrors the scaffolding constants in
  `generate.py` (frame inset 16, corner stars, nameplate baseline H−66) — if the
  scaffolding moves, the shader zones must move with it. If the whole face starts
  shimmering again, the modifier was re-attached to the composited card — move it back
  to the art layer.
  **Never write pixel-equality tests against
  the holo** — it is motion-driven and non-deterministic by design. The CoreMotion call
  must stay **attitude-only** (roll + pitch); anything health-adjacent would require
  `NSMotionUsageDescription`.
- **The deal is the only random.** All randomness in the app flows through
  `ReadingEngine` (M5) — the shuffle, the deal, and each card's fall. Do not add
  `Int.random` / `Bool.random` calls elsewhere (the M4 shell had one; M6 retired
  it — the table deals through the engine). In tests, use `SeededRNG` (splitmix64)
  so every deal is a pure function of its seed — reproducible, and the future v2
  "share the code" hook if it ever wakes up. The one sanctioned exception is the
  1.0 bonus's **reflection** (`ReadingInterpreter`): a Foundation Models session
  may be non-deterministic, but only to *read* a completed spread — never to
  choose cards, orientations, or canonical meanings. The model is commentary on
  the deal, not part of it; its sheet pauses the holo like any modal (a card
  behind it is not face-up), and "New reading" / a Siri re-deal reset it.
- **The layout is spec-driven, never size-driven** (M7): a spread's positions
  live in *card units* in `Models/Spread.swift`; `UI/SpreadLayout` scales the
  rotation-aware bounding box to fit whatever rect the table leaves. Do not
  hard-code point sizes into the table — the 17e (390×844 pt, the smallest
  supported iPhone) is the bar: "ten face-down, no overflow" is pinned in
  `SpreadTests` at exactly the 17e's card-area size, in both states. If a spread
  stops fitting, fix the spec (or the chrome) and let the engine scale.
- **The journal is the app's only growing state** (M8): `ReadingStore` keeps
  one entry per calendar day — local JSON, append-only, uncapped. A same-day
  re-save updates in place (same id, same first-saved stamp, **note
  preserved**); never add a delete, a re-date, or a cap inside the store —
  the free tier's 3-entry cap is M9's gate, applied *above* it. UI rules:
  the table's "Save to journal" row appears only when all *three* are
  revealed (the 1-card and the cross never show it — the v1 journal is the
  three-card ritual); the journal's rows render a *static* foil (their
  motion source is never started — the live holo belongs to the day's
  detail, where the cards are face-up); a hidden table pauses the holo the
  same way (no idle draw).
- **The gate is one value, consulted at three points** (M9): `Entitlement`
  (free / full) is the whole of the free/paid difference — its `deck` (22
  majors or 78), its `spreads` (two or three), its `journalCap` (3 or
  `nil` = unlimited). Route all free/paid behavior through it; do not add
  per-feature tier checks. The deal flows through the M5 engine **with
  `entitlement.deck`** — never filter the full deck in the UI. The journal cap
  is applied *above* the store (`ReadingStore` stays uncapped — M8), and a
  *same-day* re-save is never blocked (the one-per-day rule means the cap
  never strands a day — only the *next* day prompts for the unlock). The
  purchase *result* is never the grant: the UI believes
  `currentEntitlements`, and a non-consumable verify never downgrades.
  `-auguryTier full|free` (a debug launch arg, handled at the root) stands in
  for the purchase until M10's `.storekit` lands.
- **Style constants** (in `generate.py`): 540×960 canvas (9:16); background
  `#141b3f → #090e24`; starlight lines `#dfe7ff`; gold frame `#e6c79c`; stroke widths
  3.4 / 2.4 / 1.5. Seventy-eight cards that don't look like *one* deck reads as a
  hodgepodge — hold the line when refining.
- **`ArcanaID.rawValue` is the deck position**: majors 0–21, then wands 22–35,
  cups 36–49, swords 50–63, pentacles 64–77. Don't renumber — the 22/56 split and
  suit blocks derive from it.
- **The `.xcodeproj` is generated** — edit `project.yml`, regenerate, and it will
  be recreated on any checkout.

## Milestone map (full plan in `roadmap.md`)

| M | Scope | State |
|---|---|---|
| M1 | 78-card `Arcana` model | ✅ done |
| M2 | Draft generator + 78 first-pass SVGs | ✅ done |
| M3 | Refine + commit the 78 to the bundle | ✅ done — the 78 reworked one-by-one and committed (drafts + generator + catalog layers together) |
| M4 | `HoloFinish` + `MotionTilt` | ✅ done — committed: the line-layer foil (gold frame, silver name, rainbow subject/starfield) + the deal→flip→reveal shell in `ContentView` |
| M5 | `Reading` — shuffle + deal | ✅ done — `Engine/Reading.swift`: Fisher–Yates shuffle + deal + per-card fall, single injected RNG, seeded for tests; 1,000-deal fairness pinned in `ReadingTests` |
| M6 | Table → draw → flip → reveal | ✅ done — `UI/ReadingTable.swift`: 3 cards dealt face-down on launch, tap to flip under the holo, meaning panel, one shared `MotionTilt` gated on *any* face-up; 1 tap to first reveal; the M4 shell's card components moved to `UI/Card.swift` |
| M7 | All spreads (1-card, 3-card, Celtic cross) | ✅ done — `Models/Spread.swift` + `UI/SpreadLayout.swift`: picker-driven table; the cross's ten face-down fit the smallest iPhone (unit-pinned + screenshot-verified); all three ungated until M9's content gating |
| M8 | Daily journal | ✅ done — `Store/ReadingStore.swift` + `UI/JournalView.swift`: one-per-day upsert (stamp + note preserved), kill+relaunch identity, local JSON, uncapped (M9's cap is above it); the root owns the store and swaps the two rooms by opacity; save row + journal button in the table |
| M9 | Free/paid gating | ✅ done — `Store/PurchaseManager.swift` (`Entitlement`: the single gate — the deck, the spreads, the journal cap) + `UI/Paywall.swift` (the one-time $0.99, stated plainly): the table's deal + picker follow the entitlement, the save row + journal know the cap (above the uncapped store), one purchase lifts all three; 20 new tests |
| Bonus (1.0) | Siri / Shortcuts + the on-device reflection (unnumbered) | ✅ done — `Intents/AuguryIntents.swift` (two actions) + `Engine/ReadingInterpreter.swift` (Foundation Models, iOS 26+; commentary only, never the deal) + `UI/ReadingReflectionView.swift` (the sheet; pauses the holo); needs Xcode 26+ to build; 3 tests |
| M10 | The one unlock, end to end | planned → the `.storekit` config (`augury.unlock` at $0.99) + the 4/4 simulator pass + real-device sandbox (the manager + entitlement are in from M9) |
| M11–12 | Polish + App Store ship | planned |

Don't be confused about the app today: `ContentView` owns the one
`ReadingStore` and the one `PurchaseManager`, and hosts two rooms — the
table (`UI/ReadingTable`, M6, M7-spread-driven: the chosen spread dealt
face-down, flipped one at a time, each revealed under the holo with its
meaning; the layout is spec-driven through `UI/SpreadLayout`, never hard-coded
sizes; M8 adds the save row + the journal button; M9 makes the deal + picker
follow the entitlement) and the journal (`UI/JournalView`, M8: the day list,
a day reopened; M9 presents the tier-visible entries + the one unlock row).
`UI/Card.swift` holds the card components both rooms reuse. The one planned
piece still missing from the tree: the `.storekit` configuration (M10 — the
`augury.unlock` product at $0.99).

## Git & hygiene

- **Committed**: app source, tests, `project.yml`, `roadmap.md`, `README.md`, the
  canonical `drafts/*.svg`, `tools/`.
- **Gitignored (regenerable or local)**: `Augury.xcodeproj`, `build/`, `DerivedData/`,
  `xcuserdata/`, `drafts/layers/`, `drafts/_contact-sheet*.png`, `.scratch/`, `.DS_Store`.
- **The rework accumulates in the working tree, card by card** — a long uncommitted
  list of SVGs mid-pass is expected; don't be spooked by it. When you commit a
  batch, commit the reworked `drafts/*.svg` (and the `generate.py` changes) *together
  with* the matching `Assets.xcassets` layers, so the source of truth and the bundle
  never diverge.
- `generate.py` rewrites `drafts/` from its in-code specs on every run — if you
  hand-edit a draft, remember the fix must also land in `generate.py` (or be re-applied)
  or it will be lost on the next regeneration.

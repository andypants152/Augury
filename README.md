# Augury

A tarot / oracle reading app you own. A complete, hand-made deck of **78 celestial
line-art cards** with a **holographic foil finish that shifts as you tilt the device**.

**One price ($0.99), yours forever. No subscription. No account. No internet.**

> **Status: M9 + the 1.0 bonus** — the 78-card deck **in the app bundle**
> (M1–M3), the holographic finish (M4), the deal engine (M5), the
> spread-driven reading table (M6–M7): choose one card, three
> (past/present/future), or the Celtic cross — cards dealt face-down, flipped
> one at a time to reveal each under the holo, upright or inverted meaning
> included — the **daily journal** (M8): save a three-card reading as
> today's date-stamped entry, browse past days, and reopen any one of them —
> the cards flip up under the holo again and the day's note is editable —
> and **free/paid gating** (M9): one $0.99 non-consumable unlocks everything
> at once — the full 78, the Celtic cross, and the unlimited journal; the
> free tier keeps the 22 majors, the 1- and 3-card spreads, and 3 journal
> days. Plus the 1.0 bonus: two **Siri / Shortcuts** actions (start a
> reading, open the journal) and a **private, on-device reflection** on a
> completed spread (Apple Intelligence — iOS 26+ devices; generated on the
> device, never sent anywhere). The plan lives in
> [`roadmap.md`](roadmap.md).

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

Requires **Xcode 26+** with the iOS Simulator (built against Xcode 27; iOS 17
deployment target, Swift 5 language mode). The on-device reflection uses the
Foundation Models SDK — that's the Xcode 26 floor; at runtime the feature is
available only on iOS 26+ devices with Apple Intelligence, and everything
else in the app runs from iOS 17.

### StoreKit development check

The shared `Augury` Run scheme attaches `Augury/Augury.storekit`, which defines
the `augury.unlock` non-consumable at $0.99. Run the app on a simulator, tap
**Unlock**, complete the local StoreKit confirmation, then relaunch: the full
deck, Celtic cross, and unlimited journal must remain available. Reset local
transactions from Xcode's StoreKit transaction manager before repeating the
fresh-install/Restore check. The real-device sandbox flow has also been
verified against the App Store Connect product: fetch, purchase, relaunch
persistence, and Restore Purchases all looked correct.

## Layout

- `Augury/` — the app target
  - `Models/Arcana.swift` — the `Arcana` / `ArcanaID` / `Suit` types
  - `Models/ArcanaCatalog.swift` — the 78 cards (names, keywords, upright + inverted meanings)
  - `Models/Spread.swift` — the spreads: 1-card, 3-card, Celtic cross (names + prompts + layout, in deal order)
  - `Assets.xcassets` — the card art: a shared `card-bg` + one line-art layer per card (SVG sources, rasterized by `actool`)
  - `Engine/` — `HoloFinish` + `MotionTilt` (the holo, M4), `Reading` (M5: the shuffle + deal + fall — the one real random), `ReadingInterpreter` (1.0 bonus: the private, on-device reflection — Foundation Models, iOS 26+; commentary on a completed spread, never the deal) + `SiriNavigation` (1.0 bonus: the App-Intent → root handoff)
  - `Intents/` — the two Siri / Shortcuts actions (1.0 bonus)
  - `Store/` — `ReadingStore` (M8: the daily journal — one entry per day, its note, local JSON; uncapped — the free-tier cap is the M9 entitlement, above it) + `PurchaseManager` (M9: the free/paid `Entitlement` — the single gate: deck, spreads, journal cap)
  - `UI/` — the spread-driven reading table (M6–M7) + the journal (M8: the day list, a day reopened, and the save row) + the paywall (M9) + the reflection sheet (1.0 bonus): the card components + `SpreadLayout` (fits any spread to the space) + `JournalView` + `Paywall` + `ReadingReflectionView`
  - `AuguryApp.swift` / `ContentView.swift` — the app root (owns the one `ReadingStore` + `PurchaseManager`; hosts the table and the journal as two rooms)
- `AuguryTests/` — unit tests (deck, card art, the deal, the spreads, the journal store, the purchase)
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
- **Pay once.** $0.99 non-consumable, one honest unlock.

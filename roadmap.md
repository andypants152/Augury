# Augury — Roadmap

Augury is a **tarot / oracle reading app you own**. A complete, hand-made deck of 78
cards, each a **celestial line-art** piece with a **holographic foil finish that shifts
as you tilt the device**. **One price ($9.99), yours forever. No subscription. No
account. No internet.**

## Design decision: a fixed deck, made once — not runtime generation

We considered generating each card's art at runtime (a seeded composer) and **deliberately
rejected it.** Two reasons:

1. **Tarot needs recognizable imagery.** The Tower must *look* like a tower being struck;
   Death must read as Death. A runtime composer arranging abstract motifs risks a pretty
   blob that doesn't read as its arcana — that *hurts* the core use.
2. **A runtime engine is only justified by one selling point** — uniqueness ("a card no
   one else has"). Everything else (a calm, offline, pay-once reading) is fully served by
   a fixed deck, at a fraction of the build risk.

So the deck is **fixed**: 78 cards, each authored **once** (generate → draft → refine →
commit as a static SVG) and never changed. No daily rotation, no scheduled content,
nothing that changes underneath you. *The cards are made once, and done.*

### The one live layer: the holographic finish

There is exactly one runtime-rendering element, and it is a **finish, not content**:

- A lightweight **Metal shader** (iOS 17 SwiftUI `layerEffect`/`colorEffect`) applies an
  iridescent holographic foil to a *revealed* card.
- It is driven by **CoreMotion device attitude** (tilt) — so the sheen shifts continuously
  as you rotate the phone, like a real holo card in your hand.
- **This is not generation and not "daily."** The card's identity (line art + meaning) is
  still made-once-done. The holo is a transient material that reacts to light/angle. The
  made-once-done promise holds; the holo is the *feel*.

Generation is otherwise used only as a **throwaway design-time tool** to author the 78
SVGs — it is not shipped. The *uniqueness/sharing* hook stays parked as a **v2 option**
(see the end), off the critical path.

**Naming note:** *Augury* = divination by signs. Alternates: *Cartomancy*, *Sigil*.
Final pick is yours to confirm with an App Store search.

*(Sibling note: the sleep-sounds project Fathomless is on pause. This is separate.)*

---

## Design principles

1. **Made once, done.** The 78 cards are authored once and committed as static SVGs.
   No runtime generation, no daily content, no rotation. The deck is permanent.
2. **Canonical meaning.** The 78 traditional arcana, each with real upright + inverted
   meanings. Readings make sense because the message layer is timeless, not invented.
3. **Tactile, ritual feel.** The holo finish + deliberate pacing make a reading feel like
   handling a physical card. Calm, dark, quiet.
4. **Offline, no account.** No network beyond StoreKit. The deck ships in the bundle;
   your daily journal lives on the device. CoreMotion attitude needs no permission.
5. **Respect the device.** The live holo runs **only while a card is face-up**, and pauses
   otherwise — no idle battery drain. Honors **Reduce Motion** (freezes the holo to a fixed
   angle) for vestibular safety.
6. **Pay once.** $9.99 non-consumable, one honest unlock.

---

## The product (v1.0)

**The loop:** choose a spread → the app shuffles the unlocked deck and deals face-down →
you flip each card; it reveals its celestial line art **with a holo sheen that shifts as
you tilt** → meaning (upright or inverted) is shown → optionally save the reading to
your **daily journal** (one 3-card entry per day).

| | Free | $9.99 unlock (one-time) |
|---|---|---|
| Cards | 22 Major Arcana (a complete, real subset) | full 78 |
| Spreads | 1-card, 3-card (past/present/future) | + Celtic cross (10-card) |
| Inverted meanings | ✓ | ✓ |
| Holographic finish | ✓ (all cards) | ✓ |
| Daily journal | 3 saved | unlimited |

The **holo is universal** (a deliberate choice — the signature *vibe* is not paywalled;
the paywall gates *content*: cards, spreads, daily journal). The free tier is genuinely usable —
the 22 majors are a real, standalone deck.

---

## Where we are

**M1 + M2 + M3 + M4 complete.** The one-by-one rework of all 78 is done, signed off,
and committed — the deck reads as *one* deck — and the holographic finish, the one
live layer, is committed with it. The 78-card `Arcana` model + `ArcanaCatalog`
are in (tests green: 78/78 cards, 156 meanings, 22/56 split, 14 per suit, no duplicate
keywords). The draft pipeline (`tools/card-draft`) is in: deterministic
specs → 78 line-art SVGs in `drafts/`, one consistent style (indigo starfield, starlight lines,
gold frame), contact sheets at 3 sizes via
`montage.swift`.

The M3 refine was done **one card at a time, in deck order** — each card's figure
improved in `generate.py`, regenerated, synced into the asset catalog, and verified by
eye before the next one started. What the rework gave the deck:

- **Unmistakable suit motifs** (the 56 minors) — a star-tipped `wand()`, a rimmed-bowl
  `chalice()`, a slim `blade()` with a star pommel, a star-in-circle `pentacle()`: each
  suit reads as itself at contact-sheet size, and the courts (Page/Knight/Queen/King)
  keep their own compositions.
- **A distinct figure or composition for every major** — the Priestess between her
  pillars, the Emperor within his square, the Lovers' angel over the choice, the
  Chariot's opposed sphinxes, the seated lion of Strength, the Hermit on his summit;
  then the final twelve: the turning Wheel, the weighing of Justice, the Hanged Man's
  inverted figure and halo, Death as a star dying into the dawn, the angel of
  Temperance mixing two chalices, the Devil's horned star over the bound, the struck
  Tower and its exiled, the Star over the pouring figure, the moon-road between two
  towers, the Sun's child and sunflowers, the trumpet of Judgement over the rising
  dead, the dancer in the laurel of the World.
- **Identity discipline** — the specs document who owns each motif (wings: the Lovers;
  the ram: the Emperor; beasts: the Chariot/Strength; the pointed keep: the Tower; the
  fluted gate: the Priestess; the crescent bowl: the cups; the two faces: the Sun and
  the Moon), so the 78 stay one deck of distinct voices — the M3 sharp edge, held.

The deck is **in the app's bundle and render-verified**. Each card ships as two
layers in `Assets.xcassets` (sources are canonical SVGs, diffable in git):

- `card-bg` — the shared radial-glow background, stored **once** for all 79 faces.
- the card's **line-art layer** — starfield + figure + frame + nameplate on transparent.

`sync_assets.py` copies the layer split (derived by `generate.py`, gitignored) into the
catalog; `actool` rasterizes each at 3x at build time. The sparse art layers keep the
whole deck at **~8 MB** in the compiled catalog — a single full-card image per card would
be ~130 MB. All 78 render-verified in-app via a cold-launch screenshot loop (checked per
card for frame, starfield, and nameplate presence). Along the way this caught a real bug:
six majors with no-article names (Strength, Wheel of Fortune, Justice, Death, Temperance,
Judgement) resolved to nonexistent `the-*` assets and rendered as bare backgrounds —
`assetName` is now derived from the display name, with a regression test.

**M4 is done — the holo is committed.** `HoloFinish` + `MotionTilt` in `Engine/`: the
one live layer — foil on the line layer (never the ground), driven by device attitude
(a time-shimmer where there is no sensor), with per-zone palettes: gold frame, silver
nameplate, holo-foil rainbow on subject + starfield. Whisper-quiet, live only while a
card is face-up, Reduce-Motion-safe. The `ContentView` shell deals a card face-down,
flips it over on a tap (3-D flip; a crossfade under Reduce Motion), and reveals it
under the holo.

**Next: M5 — `Reading`: the shuffle + the deal** (`Engine/Reading.swift`).

---

## Architecture (fixed deck + one live finish)

| Piece | File | What it does |
|---|---|---|
| `Arcana` | `Models/Arcana.swift` | the 78: id, name, keywords, upright + inverted meaning. **The** content layer |
| Card art | `Assets.xcassets` | two layers per face: the shared `card-bg` + the card's line-art layer — canonical SVGs (in `drafts/`) that `actool` rasterizes at 3x (~8 MB). Made once, committed |
| `HoloFinish` | `Engine/HoloFinish.metal` + `Engine/HoloLayer.swift` | iridescent foil shader; samples **CoreMotion attitude** (tilt) → view angle → sheen. Live only while a card is face-up; Reduce-Motion-safe |
| `MotionTilt` | `Engine/MotionTilt.swift` | wraps `CMMotionManager`; starts/stops with card state; no usage permission needed (attitude only); simulator/no-sensor → time-based fallback shimmer |
| `Spread` | `Models/Spread.swift` | spread definitions: 1-card, 3-card, Celtic cross — positions + prompts |
| `Reading` | `Engine/Reading.swift` | shuffles the unlocked deck, deals to positions, assigns upright/inverted per card. The one real "random" (a shuffle) |
| `ReadingStore` | `Store/ReadingStore.swift` | the daily journal: 3-card draws logged per day (cards + positions + date + note); append-only, local JSON |
| `PurchaseManager` | `Store/PurchaseManager.swift` | StoreKit 2: fetch/purchase/restore; entitlement local, re-verified on launch |
| UI | `UI/*.swift` | the table, draw + flip + reveal (holo on reveal), spreads, journal, paywall card |

No backend. No composer. No codec. Card *imagery* is static; the only runtime render is
the holo finish, and the only randomness is a card shuffle.

---

## How the 78 are made (generate → draft → refine)

A one-time **design-time** pipeline — the generator is a tool in `tools/`, never shipped.
Style: **celestial line art** (moons, suns, stars, constellations, planetary/zodiac
motifs; a single consistent line weight + palette):

1. **Spec** — per arcana: a motif list (The Moon → crescent + face; The Star → radiant
   star; Tower → tower + bolt + falling figure), a celestial palette, a composition rule.
2. **Draft** — `tools/card-draft` turns each spec into a first-pass line-art SVG.
3. **Refine** — a human pass over all 78: *does it read as this arcana? is the line style
   consistent?* Fix per card. The main content work / the real production risk.
4. **Commit** — the 78 final SVGs into the bundle, done forever: `generate.py` derives
   the two-layer split (shared `card-bg` + per-card line-art layer) and `sync_assets.py`
   copies it into `Assets.xcassets`, where `actool` rasterizes it (~8 MB compiled).
   The holo is applied at render time, so the committed SVGs stay clean (no baked-in holo).

*De-risking:* stage it — the **22 majors first** (the entire free tier, a complete
product), then the 56 minors. A good draft pass keeps the refine pass short.

---

## Milestones

Sequential, small, each with a **measurable "done when"**. Art/content risk is
front-loaded (M1–M3); the holo is one focused feature (M4); after that it's a clean
reading product.

### Phase 1 — The 78 (content)

| # | Milestone (scope) | Done when (measurable) |
|---|---|---|
| **M1** | `Arcana` — all 78 with name, keywords, upright + inverted meaning | Test enumerates 78/78, every field non-empty; all 156 meaning strings pass one read-through (they must *read* right) |
| **M2** | Draft generator (`tools/card-draft`) + per-arcana celestial specs | Script emits **78 valid line-art SVGs**, one style, all render in a preview at 3 sizes with no error |
| **M3** | Refine + commit the 78 final SVGs to the bundle | 78/78 approved in a side-by-side grid (reads as arcana + consistent line style); **staged**: 22 majors first, then 56 minors |

### Phase 2 — Holo + reading engine + UX

| # | Milestone (scope) | Done when (measurable) |
|---|---|---|
| **M4** | `HoloFinish` + `MotionTilt` — iridescent foil driven by device attitude | Tilting the phone visibly shifts the holo on a face-up card at **60 fps**; CoreMotion starts/stops with card state (no idle draw); no-sensor/simulator → smooth time-based shimmer; **Reduce Motion** → fixed angle (no shimmer) |
| **M5** | `Reading` — shuffle + deal (no duplicates), upright/inverted per card | 1,000 simulated deals: a 3-card draw is always 3 *distinct* cards; each arcana's frequency is within ~2σ of uniform (no "lucky" card) |
| **M6** | Table → draw → flip → reveal (3-card), holo on reveal | ≤ 3 taps from cold launch to first revealed (holo) card; every card VoiceOver-labeled; works on the smallest supported iPhone |
| **M7** | All spreads — 1-card, 3-card, Celtic cross | Celtic cross (10 face-down) lays out with no overflow on the smallest iPhone; all spreads deal + reveal correctly |

### Phase 3 — Daily journal + purchase

| # | Milestone (scope) | Done when (measurable) |
|---|---|---|
| **M8** | **Daily journal** — `ReadingStore`: draw three cards, save as today's entry (date-stamped); list / reopen past entries (+ optional note) | Drawing three and saving them to the daily journal lands an entry dated to the day; a saved entry survives kill + relaunch and reopens identically (cards, orientations, date, note); append-only (test); free caps at 3 |
| **M9** | Free/paid gating — free = 22 majors + 2 spreads + 3 daily-journal entries; paid = 78 + all + unlimited | Free build deals only majors and enforces the daily-journal cap (tests); one purchase lifts everything; paywall states the one-time price plainly |
| **M10** | StoreKit 2 — fetch/purchase/restore + entitlement + `.storekit` + DEBUG toggle | Simulator **4/4**: product fetches; purchase ⇒ full 78 + all spreads + unlimited journal; kill + relaunch persists via `currentEntitlements`; fresh install + Restore re-grants |

### Phase 4 — Ship

| # | Milestone (scope) | Done when (measurable) |
|---|---|---|
| **M11** | Polish — ritual UI pass, holo tuning (intensity/iridescence), flip haptics, icon, launch screen, README (build, min-Xcode pin, how the SVGs were made, how the holo works), tests green, archive | Clean `xcodebuild test` from a fresh checkout; valid, signable .ipa; real-device sandbox purchase succeeds; holo holds 60 fps on the oldest supported device |
| **M12** | App Store submission (owner-only: ASC record + `augury.unlock` IAP + assets + copy; Small Business Program — already applied ✓) | **1.0 is live** |

---

## Sharp edges (what to watch)

- **Art consistency is the main content risk** (M3). Seventy-eight line-art cards that
  don't look like *one* deck reads as a hodgepodge. Lock the style on the first 5, then
  hold the line. The draft generator (M2) exists to make this pass fast.
- **Refine is the schedule** (M3). 78 hand-checked cards is the biggest single time sink —
  a *design* risk, not an engineering one. Staging (22 → 56) keeps a shippable product in
  hand early.
- **The holo must be a whisper, not a strobe** (M4/M11). Iridescence that's too strong
  reads as noise and hurts the calm. Tune intensity low; the effect should be *felt* on
  tilt, not shouted. And it must respect **Reduce Motion** and pause when no card is up
  (battery + vestibular safety).
- **Holo is non-deterministic by nature** — it's motion-driven, so app *screenshots* will
  vary by angle. That's a feature (the shimmer is the hook), not a bug; just don't write
  pixel-equality tests against it. (The card *art* under it is still the static, testable
  SVG.)
- **CoreMotion attitude needs no permission** — but confirm the exact `startDeviceMotionUpdates`
  call you use doesn't creep into a health-adjacent API that *would* need `NSMotionUsageDescription`.
- **StoreKit is the only live-untested part until a real device sandbox purchase** (M10).

---

## What "working" means (honest metrics)

No backend, so no dashboards. The signals that matter:

- **Return** — do people come back night after night? (a tarot app lives on habit)
- **Daily journaling** — daily-journal entries per user (local counter). A person who
  draws three and logs them day after day is a person who's stuck. Watch this one.
- **The holo moment** — is it shared? The tilt-to-shimmer is the most screenshot-able part
  of the app; if people film/share it, that's your free marketing engine.
- **Conversion** — free → $9.99; plus refund rate and rating from the App Store.

If people try a couple of readings and don't return, the *meanings* or the *ritual feel*
is the problem — fix the text and the pacing before anything else.

---

## v2 (the door we're keeping open)

If v1 proves the audience, the **uniqueness** hook becomes the upgrade: a *runtime*
generation option — "mint a card no one else has, it's yours, share the code" — as an
addition *on top of* the fixed deck, or a separate "generative oracle" mode. Same genome/
seed DNA as the sleep projects, now optional rather than load-bearing. Off the critical
path; revisit only after 1.0 ships and the return/conversion numbers are in.

---

## Open questions (for you)

1. **Name** — Augury / Cartomancy / Sigil? (Renaming the folder is one `mv`.)
2. **Inversions** — always allowed (traditional), or upright-only for a calmer read?
   I've defaulted to *both* in the roadmap.
3. **Holo finish scope** — I've made it **universal** (every card, both tiers) as the
   signature vibe. Say the word if you'd rather reserve it for the paid tier, or gate a
   *stronger* holo (e.g., a "foil" premium finish) behind the unlock.

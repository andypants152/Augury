import XCTest
import StoreKit
@testable import Augury

// A fake of the StoreKit seam — the only thing a test of the manager must
// stand in for the store. A `Product` cannot be constructed outside the
// framework, so `products` is always `[]` in tests; the manager's price
// fallback (the documented $0.99) is what gets pinned. `granted` is mutable
// *between* calls, so a test can model "the store hiccups" (an empty read)
// after a grant.
private final class FakeStoreKitClient: StoreKitClient {
    var products: [Product] = []
    var purchaseOutcome: PurchaseOutcome = .succeeded
    var granted: Set<String> = []
    var productRequests: [String] = []
    var purchaseCalls = 0
    var syncCalls = 0
    private var updatesContinuation: AsyncStream<String>.Continuation?

    func products(for ids: [String]) async -> [Product] {
        productRequests.append(contentsOf: ids)
        return products
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        purchaseCalls += 1
        return purchaseOutcome
    }

    func grantedProductIDs() async -> Set<String> {
        granted
    }

    func sync() async {
        syncCalls += 1
    }

    func transactionUpdates() -> AsyncStream<String> {
        AsyncStream { continuation in
            updatesContinuation = continuation
        }
    }

    func sendUpdate(productID: String) {
        updatesContinuation?.yield(productID)
    }
}

// MARK: - Entitlement (the pure half)

/// M9 — the **single entitlement**: the free/paid gate.
///
/// Done-when (from the roadmap): a fresh free build deals only majors,
/// offers two spreads, and stops the journal at 3; one purchase lifts all
/// three; the paywall states the one-time price plainly.
///
/// The gating is a pure function of the `Entitlement` value, so these bars
/// are tested directly — no product, no network, nothing to flake. This is
/// the whole of M9's testable surface: every free/paid difference in the
/// app derives from this one value, and the manager (below) is only what
/// *moves* it.
final class EntitlementTests: XCTestCase {

    let deck = Arcana.all

    // ── Gate 1 — the deck the engine shuffles from ─────────────────────

    /// Roadmap M9, bar 1 (free side): the free deck is exactly the 22
    /// majors — the complete, real subset the product table promises — and
    /// the full deck is the whole 78, unchanged.
    func testFreeDeckIsExactlyTheTwentyTwoMajors() {
        let freeDeck = Entitlement.free.deck
        XCTAssertEqual(freeDeck.count, 22, "the free tier is the 22 majors")
        XCTAssertTrue(freeDeck.allSatisfy { $0.isMajor },
                      "no minor may appear in the free deck")
        XCTAssertEqual(Set(freeDeck.map(\.id)), Set(Arcana.all.filter(\.isMajor).map(\.id)),
                       "the free deck is the majors, unmodified")

        XCTAssertEqual(Entitlement.full.deck, Arcana.all,
                       "the full deck is the whole 78, in deck order")
    }

    /// The engine half of the same bar: 100 three-card deals from the free
    /// deck are majors-only. Structural — every card the free deck contains
    /// is a major — so it can never flake; it pins the composition the
    /// engine is actually dealt.
    func testFreeDealsAreMajorsOnly_over100Deals() {
        var engine = ReadingEngine(seed: 0x9DE)
        for _ in 0..<100 {
            let reading = engine.deal(count: 3, from: Entitlement.free.deck)
            XCTAssertEqual(reading.count, 3)
            XCTAssertTrue(reading.cards.allSatisfy { $0.isMajor },
                          "a free deal must contain only majors")
        }
    }

    /// And the full deck deals the full 78 (the lift, engine half): a full
    /// 78 deal is an exact permutation of the whole deck — M5's bar, now
    /// read through the entitlement.
    func testFullDealsComeFromTheWholeDeck() {
        var engine = ReadingEngine(seed: 0x9DE)
        for _ in 0..<50 {
            let reading = engine.deal(count: 10, from: Entitlement.full.deck)
            XCTAssertEqual(reading.count, 10)
        }
        var full = ReadingEngine(seed: 0x9DE)
        let reading = full.deal(count: 78, from: Entitlement.full.deck)
        XCTAssertEqual(Set(reading.cards.map(\.id)), Set(ArcanaID.allCases),
                       "a full 78 deal must contain every card exactly once")
    }

    // ── Gate 2 — the spreads the picker offers ──────────────────────────

    /// Roadmap M9, bar 2 (free side): the free picker offers two spreads —
    /// the one-card and the three-card. The Celtic cross is the paid spread.
    func testFreeOffersExactlyTheTwoSimpleSpreads() {
        XCTAssertEqual(Entitlement.free.spreads.map(\.id), ["one-card", "three-card"])
    }

    /// Full offers all three, in the catalog's picker order.
    func testFullOffersAllThreeSpreads() {
        XCTAssertEqual(Entitlement.full.spreads.map(\.id), Spread.all.map(\.id))
        XCTAssertTrue(Entitlement.full.spreads.contains(Spread.celticCross),
                      "the Celtic cross is the paid spread")
    }

    // ── Gate 3 — the journal's cap (applied above the uncapped store) ───

    /// Roadmap M9, bar 3: free keeps 3 journal entries; full is unlimited.
    /// Unlimited is `nil`, not a big number — the store must never see a
    /// cap (its M8 invariant is uncapped; the cap lives above it).
    func testJournalCapIsThreeForFreeAndNilForFull() {
        XCTAssertEqual(Entitlement.free.journalCap, 3)
        XCTAssertNil(Entitlement.full.journalCap,
                     "full is unlimited — a cap of 10_000 would still cap")
    }

    /// `n` journal entries, **oldest first** (the store's order), each dated
    /// back a distinct number of days, each with its own seeded 3-card
    /// reading — deterministic per call.
    private func makeEntries(_ n: Int) -> [JournalEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return stride(from: n, through: 1, by: -1).map { back in
            let date = calendar.date(byAdding: .day, value: -back, to: today)!
            var engine = ReadingEngine(seed: UInt64(back))
            return JournalEntry(date: date, reading: engine.deal(count: 3, from: deck))
        }
    }

    /// The display half of the bar ("stop the journal at 3"): a free journal
    /// presents the most recent 3 days — same order in, same order out —
    /// and full presents all.
    func testFreeJournalPresentsOnlyTheThreeMostRecent() {
        let entries = makeEntries(5)
        XCTAssertEqual(Entitlement.free.visibleEntries(entries), Array(entries.suffix(3)),
                       "the free tier presents the three most recent days, in order")
        XCTAssertEqual(Entitlement.full.visibleEntries(entries), entries,
                       "full presents everything")
        // Below the cap, free presents all — the cap is a ceiling, not a floor.
        XCTAssertEqual(Entitlement.free.visibleEntries(Array(entries.prefix(2))),
                       Array(entries.prefix(2)))
    }

    /// The creation half of the bar: a *new* day is allowed only below the
    /// cap; a same-day re-save is a replace (the day count never grows — the
    /// store's one-per-day rule), so it is always allowed, even at the cap.
    func testFreeCanSaveUntilTheCap_thenOnlyReplaces() {
        XCTAssertTrue(Entitlement.free.canSaveDay(hasEntryToday: false, currentCount: 2),
                      "below the cap, a new day is allowed")
        XCTAssertTrue(Entitlement.free.canSaveDay(hasEntryToday: true, currentCount: 3),
                      "at the cap, a same-day replace stays allowed")
        XCTAssertFalse(Entitlement.free.canSaveDay(hasEntryToday: false, currentCount: 3),
                       "at the cap, a *new* day is the paywall's moment")
        XCTAssertFalse(Entitlement.free.canSaveDay(hasEntryToday: false, currentCount: 7),
                       "past the cap (a debug-seeded journal), still no new day")
        XCTAssertTrue(Entitlement.full.canSaveDay(hasEntryToday: false, currentCount: 500),
                      "full is unlimited, whatever the count")
    }

    // ── the shape of the gate ────────────────────────────────────────────

    /// The two tiers, and nothing else: free is not-full, full is full, and
    /// the whole of the free/paid difference is this one value.
    func testTheTwoTiersAreExhaustiveAndDistinct() {
        XCTAssertEqual(Tier.allCases, [.free, .full])
        XCTAssertFalse(Entitlement.free.isFull)
        XCTAssertTrue(Entitlement.full.isFull)
    }
}

// MARK: - PurchaseManager (the store-side half)

/// M9 — `PurchaseManager`: the one purchase and the entitlement it moves.
///
/// Run on the main actor (the manager is a `@MainActor` UI object, like
/// `MotionTilt`), through a `FakeStoreKitClient`. The bars pinned here are
/// the *logic* of the purchase: the outcome is never the grant (the
/// entitlement re-verifies from `currentEntitlements`), a non-consumable
/// never downgrades, and the price the paywall states is the store's own or
/// the documented $0.99. The 4/4 *simulator* pass (a real `.storekit` file)
/// is M10.
@MainActor
final class PurchaseManagerTests: XCTestCase {

    func testFreshInstallStartsFreeUntilStoreKitVerifiesTheUnlock() async {
        let client = FakeStoreKitClient()
        let manager = PurchaseManager(client: client)
        XCTAssertEqual(manager.entitlement, .free)
    }

    // ── one purchase lifts everything ───────────────────────────────────

    /// Roadmap M9, bar 2 (the lift): one purchase lifts all three gates at
    /// once — deck 22 → 78, spreads 2 → 3, journal 3 → unlimited.
    func testOnePurchaseLiftsAllThreeGates() async {
        let client = FakeStoreKitClient()
        client.purchaseOutcome = .succeeded
        client.granted = [PurchaseManager.productID]   // the entitlement lands
        let manager = PurchaseManager(client: client)
        XCTAssertEqual(manager.entitlement, .free, "a fresh install comes up free")

        await manager.purchase()

        XCTAssertEqual(manager.entitlement, .full, "one purchase lifts everything")
        XCTAssertEqual(manager.entitlement.deck.count, 78, "gate 1 lifted: the full deck")
        XCTAssertEqual(manager.entitlement.spreads.count, 3, "gate 2 lifted: all spreads")
        XCTAssertNil(manager.entitlement.journalCap, "gate 3 lifted: unlimited journal")
        XCTAssertEqual(client.purchaseCalls, 1)
    }

    /// The outcome is never the grant — the entitlement is. A cancel leaves
    /// the user free, quietly (no error line).
    func testCancelledPurchaseLeavesTheUserFree() async {
        let client = FakeStoreKitClient()
        client.purchaseOutcome = .userCancelled
        client.granted = []
        let manager = PurchaseManager(client: client)

        await manager.purchase()

        XCTAssertEqual(manager.entitlement, .free)
        XCTAssertFalse(manager.purchaseFailed, "a cancel is not a failure")
    }

    /// A failed purchase stays free *and* says so — the paywall's quiet
    /// error line.
    func testFailedPurchaseStaysFreeAndReports() async {
        let client = FakeStoreKitClient()
        client.purchaseOutcome = .failed
        client.granted = []
        let manager = PurchaseManager(client: client)

        await manager.purchase()

        XCTAssertEqual(manager.entitlement, .free)
        XCTAssertTrue(manager.purchaseFailed)
    }

    /// A pending purchase grants nothing yet (family approval, a slow
    /// network — the entitlement will land later; the next verify picks it
    /// up). No error is reported meanwhile.
    func testPendingPurchaseGrantsNothingUntilItLands() async {
        let client = FakeStoreKitClient()
        client.purchaseOutcome = .pending
        client.granted = []
        let manager = PurchaseManager(client: client)

        await manager.purchase()

        XCTAssertEqual(manager.entitlement, .free)
        XCTAssertFalse(manager.purchaseFailed)

        // Let the manager subscribe before delivering the approval, then
        // give its main-actor update task a few turns to consume it.
        await Task.yield()
        client.sendUpdate(productID: PurchaseManager.productID) // it lands while open
        for _ in 0..<10 {
            if manager.entitlement == .full { return }
            await Task.yield()
        }
        XCTFail("a verified transaction update should unlock without relaunching")
    }

    func testRestoreSyncsThenVerifiesTheUnlock() async {
        let client = FakeStoreKitClient()
        client.granted = [PurchaseManager.productID]
        let manager = PurchaseManager(client: client)

        await manager.restore()

        XCTAssertEqual(client.syncCalls, 1)
        XCTAssertEqual(manager.entitlement, .full)
    }

    /// Purchasing while already full is a no-op — a non-consumable can't be
    /// bought twice, and the manager short-circuits before the store.
    func testPurchaseWhileFullIsANoop() async {
        let client = FakeStoreKitClient()
        client.granted = [PurchaseManager.productID]
        let manager = PurchaseManager(client: client)
        await manager.verify()
        XCTAssertEqual(manager.entitlement, .full)

        let outcome = await manager.purchase()

        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(client.purchaseCalls, 0, "no store round-trip when already full")
    }

    // ── re-verification: the launch + the permanent purchase ────────────

    /// Launch re-verify: an account that holds the unlock comes up full
    /// (among other entitlements).
    func testVerifyGrantsFullFromCurrentEntitlements() async {
        let client = FakeStoreKitClient()
        client.granted = [PurchaseManager.productID, "some.other.product"]
        let manager = PurchaseManager(client: client)

        await manager.verify()

        XCTAssertEqual(manager.entitlement, .full)
    }

    /// An account without the unlock stays free.
    func testVerifyWithoutTheUnlockStaysFree() async {
        let client = FakeStoreKitClient()
        client.granted = ["some.other.product"]
        let manager = PurchaseManager(client: client)

        await manager.verify()

        XCTAssertEqual(manager.entitlement, .free)
    }

    /// A non-consumable is permanent: a transient empty read after a grant
    /// must never revoke it. (The roadmap's "kill + relaunch persists" bar
    /// in its unit form — M10's 4/4 exercises the same guarantee through
    /// the real store.)
    func testVerifyNeverDowngradesAGrantedEntitlement() async {
        let client = FakeStoreKitClient()
        client.granted = [PurchaseManager.productID]
        let manager = PurchaseManager(client: client)

        await manager.verify()
        XCTAssertEqual(manager.entitlement, .full)

        client.granted = []   // the store hiccups
        await manager.verify()
        XCTAssertEqual(manager.entitlement, .full,
                       "a non-consumable is permanent — verify must never downgrade")
    }

    // ── launch: fetch, then verify ──────────────────────────────────────

    /// The launch sequence: load the product (for the paywall's price), then
    /// re-verify the entitlement — the order both depend on.
    func testStartFetchesThenVerifies() async {
        let client = FakeStoreKitClient()
        client.granted = [PurchaseManager.productID]
        let manager = PurchaseManager(client: client)

        await manager.start()

        XCTAssertEqual(client.productRequests, [PurchaseManager.productID])
        XCTAssertEqual(manager.entitlement, .full)
    }

    // ── the price: stated plainly ───────────────────────────────────────

    /// The paywall states the one-time price plainly: the store's own
    /// (`displayPrice`) once it has loaded, the documented intent until
    /// then. A `Product` cannot be constructed in a unit test, so the
    /// fetchable half of this is M10's `.storekit` + simulator; the fallback
    /// — the number the roadmap, the App Store, and the paywall agree on —
    /// is pinned here. (It is $0.99 by the owner's re-pricing: a deck of
    /// this shape is a coffee, not a hundred lattes. Change the constant in
    /// `PurchaseManager` and this test changes with it — that is the point.)
    func testPriceFallsBackToTheDocumentedIntent() async {
        let client = FakeStoreKitClient()   // the store has no product
        let manager = PurchaseManager(client: client)

        await manager.fetchProducts()

        XCTAssertNil(manager.product)
        XCTAssertEqual(manager.displayPrice, PurchaseManager.intendedPrice)
        XCTAssertEqual(manager.displayPrice, "$0.99")
    }

    /// The one unlock is the documented non-consumable id (roadmap M12:
    /// "augury.unlock IAP") — a rename here would silently break the store
    /// configuration, so the literal is pinned.
    func testTheOneUnlockIsTheDocumentedProductID() {
        XCTAssertEqual(PurchaseManager.productID, "augury.unlock")
    }
}

import XCTest
import StoreKitTest

// MARK: - M10 — the one unlock, end to end, against a *real* store

/// A `SKTestSession` attaches `Augury/Augury.storekit` (the `augury.unlock`
/// non-consumable at $0.99) to this simulator test. This exercises the *real* `DefaultStoreKitClient`
/// path end to end: a real product fetch, a real purchase in the simulator,
/// real entitlement verification, real persistence.
///
/// The simulator's store state persists across launches — and across app
/// reinstalls, because a non-consumable belongs to the *store's* account, not
/// the app install — so the test adapts to the state it finds:
///
///   - launched **free** (a store that does not own the product): the full
///     bar — the paywall prices (the fetch), the purchase lifts the single
///     entitlement (full 78 + all spreads + unlimited journal), kill +
///     relaunch persists via `currentEntitlements`.
///   - launched **full** (a fresh install over a store that already owns it —
///     the "fresh install + restore" bar): the launch verification must
///     re-grant full. (In this design the launch verify *is* the restore —
///     a non-consumable is permanent and the store is the source of truth,
///     so the app never waits for the user to tap a restore button; the
///     button remains for the user's peace of mind.)
final class UnlockFlowTests: XCTestCase {

    private var app: XCUIApplication!
    private var store: SKTestSession!

    /// The header's unlock button (M9) and the cross picker segment (M7) —
    /// the two observable faces of the one entitlement.
    private var unlockHeader: XCUIElement {
        app.buttons["Unlock the full deck, the Celtic cross, and unlimited journal, one time"]
    }
    private var crossPicker: XCUIElement {
        app.buttons["Celtic Cross drawing type"]
    }

    override func setUpWithError() throws {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Augury", withExtension: "storekit"))
        store = try SKTestSession(contentsOf: fixture)
        // The test drives the app's own buy button; StoreKit completes its
        // local confirmation silently so this remains deterministic in CI.
        store.disableDialogs = true
        store.clearTransactions()
    }

    override func tearDown() {
        // Leave no running app behind: a live app (holo sheet, purchase
        // sheet mid-flight) keeps the simulator from going idle, and
        // xcodebuild will burn ten minutes trying to collect diagnostics.
        app?.terminate()
        super.tearDown()
    }

    // MARK: The flow

    func testOneUnlockEndToEnd() {
        app.launch()

        // Give the launch verification time to resolve and *settle*. It is
        // local (a product fetch from the bundled storekit file, a
        // `currentEntitlements` read), so this is fast in practice; the
        // window just has to cover the free → full flip when there is one.
        waitUntil(timeout: 15) { self.crossPicker.isHittable }

        if self.crossPicker.isHittable {
            // The store already owns the product (a previous run of this
            // test, or a purchase on this simulator): the launch verify
            // re-granted. That is the "fresh install + restore" bar.
            runAlreadyOwnsFlow()
        } else {
            // A store that does not own the product: run the whole bar.
            runFreeToFullFlow()
        }
    }

    // MARK: Bar 1 + 2 + 3 — free ⇒ purchase ⇒ full ⇒ relaunch

    private func runFreeToFullFlow() {
        // Free chrome: the cross is not offered, the upsell is.
        XCTAssertFalse(crossPicker.isHittable, "a free launch must not offer the Celtic cross")
        XCTAssertTrue(unlockHeader.isHittable, "a free launch must offer the one unlock")

        // Bar 1 — the product fetches: the paywall prices. (The local
        // $0.99 and the documented fallback read the same in English; the
        // purchase itself is the real proof of the fetch — it cannot
        // succeed without the product existing in the store.)
        unlockHeader.tap()
        let buy = app.buttons["Unlock Augury for $0.99, one time"]
        waitUntil(timeout: 15) { buy.isHittable }
        XCTAssertTrue(buy.isHittable, "the paywall must price the fetched product")
        buy.tap()

        // Bar 1, observed from the outcome: no purchase error means the
        // product was fetchable and the purchase completed. (The local
        // $0.99 and the documented fallback read the same in English, so
        // the price text alone cannot distinguish them; this can.)
        let error = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'didn\\'t complete'")).firstMatch
        XCTAssertFalse(error.exists, "the product must be fetchable — no purchase error")

        // Bar 2 — the purchase lifts the single entitlement: the paywall
        // closes on its own, and the table re-deals full — all three
        // spreads offered, the upsell gone. (The full 78 and the unlimited
        // journal are the same value; the unit tests pin that mapping, and
        // the cross picker is the entitlement's visible face here.)
        waitUntil(timeout: 30) { self.crossPicker.isHittable && !self.unlockHeader.exists }
        XCTAssertTrue(crossPicker.isHittable, "the purchase must unlock the Celtic cross")
        XCTAssertFalse(unlockHeader.exists, "the purchase must remove the upsell")

        // Bar 3 — kill + relaunch persists via `currentEntitlements`.
        app.terminate()
        app.launch()
        waitUntil(timeout: 30) { self.crossPicker.isHittable && !self.unlockHeader.exists }
        XCTAssertTrue(crossPicker.isHittable, "a relaunched app must come back full")
    }

    // MARK: Bar 4 — a fresh install over a store that owns the product

    private func runAlreadyOwnsFlow() {
        XCTAssertFalse(unlockHeader.exists, "the launch verify must have re-granted full")
        // And it must hold across a relaunch — the same persistence bar,
        // observed from the other direction.
        app.terminate()
        app.launch()
        waitUntil(timeout: 30) { self.crossPicker.isHittable }
        XCTAssertTrue(crossPicker.isHittable, "a relaunched app must stay full")
    }

    // MARK: Polling

    /// Poll a UI condition until it holds or the timeout expires. (XCUITest
    /// has no `waitUntil` of its own for arbitrary conditions; a 0.25 s
    /// pump keeps the sheet's presentation animating while we wait.)
    private func waitUntil(timeout: TimeInterval, _ condition: @escaping () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        }
    }
}

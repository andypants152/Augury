import Foundation
import Combine
import StoreKit

// MARK: - Tier
//
// The two states of the product. `free` is the download — a complete, real
// subset, not a crippled one (the 22 majors are a standalone deck). `full` is
// everything, forever, for one purchase.

/// One tier of the product.
enum Tier: String, Codable, Hashable, CaseIterable {
    case free
    case full
}

// MARK: - Entitlement

/// The app's **single entitlement**: what the one purchase unlocks.
///
/// Everything that varies between the free and the full product derives from
/// one `Tier`, so the three gate points — which cards the engine shuffles
/// from, which spreads the picker offers, how many journal entries are kept
/// — always agree. (Roadmap M9: "the gate is a single entitlement consulted
/// at three points".)
///
/// The entitlement is *derived, never stored*: the source of truth is
/// StoreKit's `currentEntitlements` (a non-consumable is permanent, and a
/// relaunch must re-verify it — M10's 4/4). This pure value type is what
/// makes the whole gate testable without a product.
struct Entitlement: Hashable, Codable {
    var tier: Tier

    static let free = Entitlement(tier: .free)
    static let full = Entitlement(tier: .full)

    var isFull: Bool { tier == .full }

    // MARK: The three gate points

    /// **Gate 1 — the deck the deal engine shuffles from.** The free tier is
    /// the 22 majors (a complete, real subset); full is the 78.
    var deck: [Arcana] {
        isFull ? Arcana.all : Arcana.all.filter(\.isMajor)
    }

    /// **Gate 2 — the spreads the picker offers.** The free tier gets the
    /// one-card and the three-card; the Celtic cross is the paid spread.
    var spreads: [Spread] {
        isFull ? Spread.all : Spread.all.filter { $0.id != Spread.celticCross.id }
    }

    /// **Gate 3 — the journal's cap**, applied *above* the store (the store
    /// itself is uncapped and append-only — M8's invariant is untouched):
    /// 3 for free, `nil` (unlimited) for full.
    var journalCap: Int? {
        isFull ? nil : 3
    }

    // MARK: Gate 3, applied

    /// The entries the tier *presents*: the most recent `journalCap` (all,
    /// when unlimited). Input is the store's oldest-first order; the output
    /// keeps it (the journal list reverses for its newest-first display).
    /// The store keeps everything — this is the cap the user experiences.
    func visibleEntries(_ entries: [JournalEntry]) -> [JournalEntry] {
        guard let cap = journalCap, entries.count > cap else { return entries }
        return Array(entries.suffix(cap))
    }

    /// Whether the tier may save *today*. A day that already has an entry is
    /// a same-day **replace** (the day count never grows — the store's
    /// one-per-day rule), so it is always allowed; a *new* day is allowed
    /// only while below the cap. This is what "stops the journal at 3"
    /// means: a free user cannot grow past three days.
    func canSaveDay(hasEntryToday: Bool, currentCount: Int) -> Bool {
        if hasEntryToday { return true }
        guard let cap = journalCap else { return true }
        return currentCount < cap
    }
}

// MARK: - PurchaseOutcome

/// What a purchase attempt ended in.
///
/// The manager never *grants* on this alone — it re-verifies
/// `currentEntitlements` afterward — so a cancel or a pending never wrongly
/// unlocks, and a success unlocks exactly when the entitlement lands.
enum PurchaseOutcome: Equatable {
    case succeeded
    case userCancelled
    case pending
    case failed
}

// MARK: - StoreKitClient

/// The narrow seam over StoreKit 2 — the only thing in the app that touches
/// the store, and the only thing tests must fake. Everything above it (the
/// entitlement, the three gates, the price) is a pure function of values.
protocol StoreKitClient: AnyObject {
    /// Load the given products from the store. An empty array when none are
    /// available (an unknown product id, or the store is unreachable) — the
    /// paywall then falls back to the documented price.
    func products(for ids: [String]) async -> [Product]
    /// Purchase the product with the given id.
    func purchase(productID: String) async -> PurchaseOutcome
    /// The product ids the account currently holds
    /// (`Transaction.currentEntitlements`, collected to ids so the seam —
    /// and the tests — never need to construct framework types).
    func grantedProductIDs() async -> Set<String>
}

/// The real store: StoreKit 2.
final class DefaultStoreKitClient: StoreKitClient {

    func products(for ids: [String]) async -> [Product] {
        (try? await Product.products(for: ids)) ?? []
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        guard let product = (try? await Product.products(for: [productID]))?.first else {
            return .failed
        }
        do {
            switch try await product.purchase() {
            case .success: return .succeeded
            case .userCancelled: return .userCancelled
            case .pending: return .pending
            @unknown default: return .failed
            }
        } catch {
            return .failed
        }
    }

    func grantedProductIDs() async -> Set<String> {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            // Only *verified* transactions grant: an unverified (tampered
            // or unreadable) receipt must never unlock the deck. (In the
            // current SDK, entitlements arrive as `VerificationResult`s;
            // the simulator and the App Store both deliver verified.)
            if case .verified(let transaction) = result {
                ids.insert(transaction.productID)
            }
        }
        return ids
    }
}

// MARK: - PurchaseManager

/// The one purchase (roadmap M9): the app's single non-consumable, and the
/// `Entitlement` everything reads.
///
/// Free is a real product (22 majors, two spreads, a 3-day journal); one
/// purchase lifts all three gates at once. A non-consumable is **permanent**,
/// so the manager only ever moves free → full — it never downgrades (a
/// transient empty read must not revoke a purchase). The entitlement is
/// re-verified on launch from `currentEntitlements`, so a relaunch never
/// loses it.
///
/// M10 finishes the store-side story (the `.storekit` file, the restore
/// sheet, the 4/4 simulator pass); M9 delivers the entitlement, the three
/// gates, and the paywall.
@MainActor
final class PurchaseManager: ObservableObject {

    /// The one unlock: a non-consumable, created in App Store Connect (M12)
    /// and in the local `.storekit` file (M10).
    static let productID = "augury.unlock"

    /// The one-time price as the app intends it — a single source of truth,
    /// and the paywall's fallback until (or if) the store's own price fails
    /// to load. **Must match** the price in App Store Connect and the M10
    /// `.storekit` file. (The roadmap's $9.99 was re-priced to $0.99 — a
    /// deck of this shape is a coffee, not a hundred lattes.)
    static let intendedPrice = "$0.99"

    /// The gate. Free on launch; lifted by the one purchase, re-verified on
    /// every launch. Every free/paid difference in the app reads this.
    @Published private(set) var entitlement: Entitlement = .free

    /// The loaded product — the paywall prefers its `displayPrice` (the
    /// store's own, localized price) over `intendedPrice`.
    @Published private(set) var product: Product?

    /// `true` while a purchase is in flight (the paywall's button state).
    @Published private(set) var isPurchasing = false

    /// The last purchase failed and the entitlement did not land — the
    /// paywall's quiet error line.
    @Published private(set) var purchaseFailed = false

    private let client: StoreKitClient

    init(client: StoreKitClient = DefaultStoreKitClient()) {
        self.client = client
    }

    /// The price the paywall states: the store's own once it has loaded,
    /// the documented intent until then.
    var displayPrice: String {
        product?.displayPrice ?? Self.intendedPrice
    }

    // MARK: Launch

    /// Load the product, then re-verify the entitlement. A fresh install
    /// comes up free; an account that owns the unlock comes up full.
    func start() async {
        await fetchProducts()
        await verify()
    }

    // MARK: The store

    /// Fetch the one product (for the paywall's price).
    func fetchProducts() async {
        product = await client.products(for: [Self.productID]).first
    }

    /// The one purchase. The outcome is never trusted for granting — the
    /// entitlement re-verifies from `currentEntitlements` — so a cancel or a
    /// pending never unlocks, and a success does, as soon as it lands.
    func purchase() async -> PurchaseOutcome {
        guard !entitlement.isFull else { return .succeeded }
        isPurchasing = true
        purchaseFailed = false
        defer { isPurchasing = false }
        let outcome = await client.purchase(productID: Self.productID)
        await verify()
        // If the verify already granted (the entitlement landed), there is
        // no failure to report — even for a `.failed` outcome.
        purchaseFailed = (outcome == .failed) && !entitlement.isFull
        return outcome
    }

    /// Re-verify from the account's current entitlements. Only ever lifts
    /// free → full; it never downgrades (a non-consumable is permanent).
    func verify() async {
        guard !entitlement.isFull else { return }
        let granted = await client.grantedProductIDs()
        if granted.contains(Self.productID) {
            entitlement = .full
        }
    }

    /// "Restore purchase": re-run the verify. (The classic App Store restore
    /// sheet + the 4/4 simulator pass is M10; this is M9's form — for a
    /// non-consumable, `currentEntitlements` is what a relaunch re-grants.)
    func restore() async {
        await verify()
    }

    // MARK: Verification hook

    #if DEBUG
    /// Screenshot pass (roadmap M9): force a tier from a launch argument,
    /// so the gated UI can be seen without a sandbox purchase (the
    /// store-side purchase is M10's `.storekit` work). Never built into
    /// release.
    func setTierForDebug(_ tier: Tier) {
        entitlement = Entitlement(tier: tier)
    }
    #endif
}

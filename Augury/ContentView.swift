import SwiftUI

/// The app root (M8): two quiet rooms in the same dark house — the reading
/// **table** and the daily **journal** — never both at once, never far apart.
///
/// The root owns the one `ReadingStore` (the app's only growing state) so
/// the table (which saves) and the journal (which lists, reopens, and notes)
/// share it, and the one `PurchaseManager` (M9) so both rooms read the same
/// entitlement — the single gate behind the free/paid difference. It swaps
/// the two rooms with a crossfade. Both stay in the hierarchy
/// (opacity-toggled, not removed) so a trip to the journal never loses the
/// table's deal — the ritual resumes exactly where it left off — and the
/// table's holo pauses while hidden (a hidden card is not a face-up card:
/// no CoreMotion, no idle draw).
struct ContentView: View {

    private enum Route { case table, journal }

    /// The daily journal (M8) — the app's only persistent, growing state.
    /// Created once here, shared with both rooms through the environment.
    @StateObject private var store = ReadingStore()
    /// The one unlock (M9) — the entitlement the table and the journal read.
    /// Created once here, shared with both rooms through the environment.
    @StateObject private var purchase = PurchaseManager()
    @State private var route: Route = .table
    #if DEBUG
    @State private var seededJournal = false
    #endif

    /// An explicit `init()` (rather than the implicit memberwise one, which
    /// goes private the moment every property does) so the app's `@main`
    /// can still construct the root from another file.
    init() {}

    var body: some View {
        ZStack {
            ReadingTable(isHidden: route == .journal,
                         onOpenJournal: { route = .journal })
                .opacity(route == .table ? 1 : 0)
                .allowsHitTesting(route == .table)
                .accessibilityHidden(route != .table)

            JournalView(onBack: { route = .table })
                .opacity(route == .journal ? 1 : 0)
                .allowsHitTesting(route == .journal)
                .accessibilityHidden(route != .journal)
        }
        .environmentObject(purchase)
        .environmentObject(store)
        .animation(.easeInOut(duration: 0.22), value: route)
        // Launch: load the product, re-verify the entitlement (a fresh
        // install comes up free; an owned unlock comes up full).
        .task { await purchase.start() }
        #if DEBUG
        .onAppear(perform: applyDebugHook)
        #endif
    }

    // MARK: Verification hook

    #if DEBUG
    /// Launch arguments for screenshot passes (the M8 hook, M9-extended —
    /// siblings of the table's `-augurySpread` / `-auguryCard` /
    /// `-auguryRevealed`):
    ///   `-auguryJournal <n>` — pre-populate the journal with `n` seeded
    ///                          entries, `n` days back from today (the oldest
    ///                          gets a note), so the list and a detail can be
    ///                          pinned without touching a live save
    ///   `-auguryJournalOpen` — open directly on the journal
    ///   `-auguryTier free|full` — force the entitlement, so the gated UI
    ///                             can be seen without a sandbox purchase
    ///                             (the store-side purchase is M10's work)
    private func applyDebugHook() {
        guard !seededJournal else { return }
        seededJournal = true

        if let raw = launchArg("-auguryJournal"), let n = Int(raw), n > 0 {
            var engine = ReadingEngine(seed: 0x50C0DE)
            for back in stride(from: n, through: 1, by: -1) {
                guard let date = Calendar.current.date(byAdding: .day, value: -back, to: Date()) else { continue }
                let entry = store.save(engine.deal(count: 3, from: Arcana.all), date: date)
                if back == n {
                    store.setNote("A quiet day; the cards agreed with the weather.", for: entry.id)
                }
            }
        }
        if let raw = launchArg("-auguryTier") {
            switch raw.lowercased() {
            case "full", "paid", "unlocked":
                purchase.setTierForDebug(.full)
            case "free":
                purchase.setTierForDebug(.free)
            default:
                break
            }
        }
        if CommandLine.arguments.contains("-auguryJournalOpen") {
            route = .journal
        }
    }

    /// A `-auguryFoo value` or `-auguryFoo=value` launch argument
    /// (the table's hook has its own copy of this; the flags live in two
    /// rooms now, so the little parser does too).
    private func launchArg(_ flag: String) -> String? {
        if let i = CommandLine.arguments.firstIndex(where: { $0 == flag }),
           i + 1 < CommandLine.arguments.count {
            return CommandLine.arguments[i + 1]
        }
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix(flag + "=") }) {
            return String(arg.dropFirst(flag.count + 1))
        }
        return nil
    }
    #endif
}

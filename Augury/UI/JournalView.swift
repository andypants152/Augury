import SwiftUI

// MARK: - JournalView (the list)

/// The daily journal (M8): the log of saved readings, one per day.
///
/// A quiet archive, in the house's own dark idiom (custom chrome, no nav
/// bar — same look language as the table). Each row is a day: its stamp,
/// the three cards it kept (a small static foil — the *live* holo belongs
/// to the detail, where the cards are face-up and the sensor is running),
/// and a sliver of the day's note if there is one. Tap a row to reopen the
/// day: the cards flip over under the holo again, exactly as on the table.
///
/// The root (`ContentView`) keeps the journal alive behind the table
/// (opacity-toggled, not removed), so a trip here never costs the table its
/// deal. The store arrives from the environment — the root owns the one
/// `ReadingStore` the table and the journal share.
struct JournalView: View {
    @EnvironmentObject private var store: ReadingStore
    /// The one unlock (M9): the journal presents what the tier keeps —
    /// the most recent 3 days free, all of them full.
    @EnvironmentObject private var purchase: PurchaseManager

    /// Back to the table (the root's route change).
    var onBack: () -> Void = {}

    /// The day the detail shows, if any — and the last day opened, kept so
    /// the detail's state (its flip, its note field) survives a back-and-
    /// forth instead of resetting.
    @State private var selected: JournalEntry.ID?
    @State private var lastSelected: JournalEntry.ID?

    /// The paywall (M9) — presented when a free user at the 3-day cap taps
    /// the unlock row.
    @State private var showingPaywall = false
    @State private var showingWeeklyReading = false

    /// The rows' mini-cards borrow a motion source that is **never started**:
    /// an archive row is not a face-up card, so the holo sits paused (no
    /// CoreMotion, no idle draw — the detail owns the live sheen).
    @StateObject private var rowTilt = MotionTilt()
    @StateObject private var weeklyInterpreter = WeeklyReadingInterpreter()

    /// The store arrives from the environment (the root owns it); the only
    /// injected dependency is the back route. An explicit init — the
    /// `@EnvironmentObject` property makes the implicit memberwise one
    /// private, and the root constructs this from another file.
    init(onBack: @escaping () -> Void = {}) {
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            list
                .opacity(selected == nil ? 1 : 0)
                .allowsHitTesting(selected == nil)
                .accessibilityHidden(selected != nil)

            if let id = lastSelected {
                JournalDetailView(entryID: id,
                                  isActive: selected == id,
                                  onBack: { selected = nil })
                    // A detail owns reveal, focus, note-field, and motion
                    // state. A newly selected day must not inherit any of
                    // that state from the day opened before it.
                    .id(id)
                    .opacity(selected == id ? 1 : 0)
                    .allowsHitTesting(selected == id)
                    .accessibilityHidden(selected != id)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selected)
        .fullScreenCover(isPresented: $showingPaywall) {
            Paywall(purchase: purchase) { showingPaywall = false }
        }
        .sheet(isPresented: $showingWeeklyReading) {
            WeeklyReadingView(entries: weeklyEntries,
                              interpreter: weeklyInterpreter,
                              onDismiss: { showingWeeklyReading = false })
                .presentationDetents([.medium, .large])
        }
        #if DEBUG
        // onChange, not onAppear: this room appears *before* the root seeds
        // the journal, so the hook keys off the store's first publish.
        .onChange(of: store.entries.count) { _, _ in applyDebugHook() }
        #endif
    }

    // MARK: Gate 3 (M9), applied

    /// What the tier presents from the journal: the most recent 3 days free,
    /// all of them full. The store stays uncapped (append-only, M8) — this
    /// is the cap the user experiences, applied above it.
    private var visible: [JournalEntry] {
        purchase.entitlement.visibleEntries(store.entries)
    }

    /// This follows the tier-presented entries, so a weekly reflection never
    /// gives the model access to journal days the current entitlement hides.
    private var weeklyEntries: [JournalEntry] {
        WeeklyJournal.entries(from: visible)
    }

    /// A free user at the cap: the list's quiet upsell. (Full never shows
    /// it — the cap is `nil` there; and below the cap the journal is as
    /// quiet as it has always been.)
    private var atCap: Bool {
        guard !purchase.entitlement.isFull, let cap = purchase.entitlement.journalCap else { return false }
        return store.entries.count >= cap
    }

    // MARK: Verification hook

    #if DEBUG
    /// Launch arguments for screenshot passes (the M8 hook):
    ///   `-auguryJournalDetail` — open the most recent day's detail directly
    private func applyDebugHook() {
        if CommandLine.arguments.contains("-auguryJournalDetail"),
           let newest = store.entries.last, selected == nil {
            select(newest)
        }
    }
    #endif

    // MARK: The list

    private var list: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                if visible.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if atCap {
                                unlockRow
                            }
                            ForEach(visible.reversed()) { entry in
                                row(entry)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private var header: some View {
        ZStack {
            Text("Journal")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 4)
            HStack {
                Button(action: onBack) {
                    Label("Table", systemImage: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .accessibilityLabel("Back to the reading table")
                Spacer()
                Button {
                    weeklyInterpreter.reset()
                    showingWeeklyReading = true
                } label: {
                    Label("Weekly", systemImage: "sparkles")
                        .font(.body.weight(.medium))
                        .foregroundStyle(weeklyEntries.isEmpty ? .white.opacity(0.25) : ReadingTable.uprightInk)
                }
                .disabled(weeklyEntries.isEmpty)
                .accessibilityLabel("Weekly reading")
                .accessibilityHint(weeklyEntries.isEmpty
                    ? "Save a three-card reading this week to enable this."
                    : "Reflect on this week's saved cards and journal notes.")
            }
            .padding(.horizontal, 14)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book")
                .font(.system(size: 34))
                .foregroundStyle(ReadingTable.uprightInk.opacity(0.55))
            Text("Your journal is empty")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text("Save a three-card reading to begin the day.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onBack) {
                Label("Deal a reading", systemImage: "sparkles")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15)))
            }
            .padding(.top, 8)
            .accessibilityLabel("Deal a reading, back at the table")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
    }

    /// The free tier at its cap: the journal's quiet upsell (M9) — the
    /// 3-day limit, and the one purchase past it. A full user never sees
    /// it; a free user below the cap never sees it either.
    private var unlockRow: some View {
        Button(action: { showingPaywall = true }) {
            HStack(spacing: 8) {
                Image(systemName: "lock")
                    .font(.footnote.weight(.semibold))
                Text("The free journal keeps 3 days — unlock unlimited")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .foregroundStyle(ReadingTable.uprightInk.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ReadingTable.uprightInk.opacity(0.2)))
        }
        .accessibilityLabel("The free journal keeps three days. Unlock unlimited journal, one time.")
    }

    /// One day: its stamp, its three cards, its note sliver.
    private func row(_ entry: JournalEntry) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                let w: CGFloat = 26
                ForEach(Array(entry.reading.draws.enumerated()), id: \.offset) { _, drawn in
                    CardFace(arcana: drawn.card, orientation: drawn.orientation, tilt: rowTilt, isFaceUp: false)
                        .frame(width: w, height: w * 16.0 / 9.0)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.12)))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.dateLabel(for: entry.date))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture { select(entry) }
        // One VoiceOver element per day (the table's one-element-per-card rule).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel(entry))
        .accessibilityAddTraits(.isButton)
    }

    private func rowLabel(_ entry: JournalEntry) -> String {
        let cards = entry.reading.draws
            .map { "\($0.card.name), \($0.orientation.label)" }
            .joined(separator: ", ")
        let note = entry.note.map { ". \($0)" } ?? ""
        return "\(Self.dateLabel(for: entry.date)): \(cards)\(note). Double tap to reopen."
    }

    private func select(_ entry: JournalEntry) {
        selected = entry.id
        lastSelected = entry.id
    }

    // MARK: Date labels

    /// The journal's day stamp: "Today", "Yesterday", then "Tue, Jun 3"
    /// (with the year once it leaves this year).
    static func dateLabel(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        if day == today { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday {
            return "Yesterday"
        }
        let isThisYear = calendar.component(.year, from: date) == calendar.component(.year, from: Date())
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = isThisYear ? "EEE, MMM d" : "EEE, MMM d, y"
        return f.string(from: date)
    }
}

// MARK: - JournalDetailView (one day, reopened)

/// A saved day, reopened: the three cards flip over again (under the holo,
/// as on the table — the ritual repeats) and their meanings can be reread,
/// one at a time; the day's note sits below, editable.
///
/// The detail is *always* in the hierarchy (the list and the detail are
/// opacity-toggled siblings in `JournalView`), so `isActive` — "am I the
/// day being shown?" — drives the ritual: `true` flips the cards up and
/// starts the motion sensor; `false` (the day was left) flips them back
/// over and stops it. No idle draw either way.
struct JournalDetailView: View {
    @EnvironmentObject private var store: ReadingStore

    let entryID: UUID
    /// Whether this day is the one on screen (drives the flip + the holo).
    var isActive: Bool
    var onBack: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// One motion source for the day's three cards (the table's pattern:
    /// a few cards, one sensor) — live only while this day is shown.
    @StateObject private var tilt = MotionTilt()

    /// Each card's revealed state — the flip is the ritual, replayed on
    /// every opening (and reversed on the way out).
    @State private var faceUp: [Bool] = [false, false, false]
    /// The card whose meaning the panel shows — the last one tapped.
    @State private var focus: Int = 0
    /// The note field, seeded from the entry and committed on submit.
    @State private var noteText = ""
    @State private var noteSeeded = false
    /// The detail remains mounted while hidden so its card state survives;
    /// this explicit focus state makes sure its keyboard does not survive too.
    @FocusState private var noteFocused: Bool

    /// The entry, always read live from the store — a committed note shows
    /// up here without a view-identity shuffle.
    private var entry: JournalEntry? { store.entry(for: entryID) }

    /// An explicit init (the `@EnvironmentObject` property would otherwise
    /// make the implicit memberwise one private).
    init(entryID: JournalEntry.ID,
         isActive: Bool,
         onBack: @escaping () -> Void = {}) {
        self.entryID = entryID
        self.isActive = isActive
        self.onBack = onBack
    }

    /// The holo/motion state: the day's cards are face-up *while shown*.
    private var live: Bool { isActive && scenePhase == .active }

    /// The gap between the three columns.
    private let cardGap: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            // Equal thirds from the *screen width* (not the leftover height):
            // the meaning panel and the note below need their own space, and
            // the 17e (390 pt, the smallest supported iPhone) is the bar.
            let cardW = (geo.size.width - 28 - 2 * cardGap) / 3
            let cardH = cardW * 16.0 / 9.0

            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        cardRow(cardW: cardW, cardH: cardH)
                        meaningPanel
                        reflectionSection
                        noteSection
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            seedStateFromEntry()
            // `onChange` only observes transitions after the view exists;
            // the first selected entry arrives already active. Start its
            // shared motion source here as well, rather than leaving the
            // first reopened day in the no-sensor state.
            tilt.setFaceUp(live)
        }
        // The ritual, in and out: opening the day flips the three up
        // (staggered); leaving flips them back down. Under Reduce Motion the
        // `RevealCard` crossfades instead, and the holo sits frozen.
        .onChange(of: isActive) { _, active in
            if !active { noteFocused = false }
            for i in faceUp.indices where faceUp[i] != active {
                withAnimation(flip.delay(Double(i) * 0.12)) {
                    faceUp[i] = active
                }
            }
        }
        // The sensor starts/stops with the day (one sensor for three cards).
        .onChange(of: live) { _, isLive in
            tilt.setFaceUp(isLive)
        }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text(JournalView.dateLabel(for: entry?.date ?? Date()))
                .font(.title2.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 4)
            HStack {
                Button(action: onBack) {
                    Label("Journal", systemImage: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .accessibilityLabel("Back to the journal")
                Spacer()
            }
            .padding(.horizontal, 14)
        }
    }

    // MARK: The three cards

    private func cardRow(cardW: CGFloat, cardH: CGFloat) -> some View {
        HStack(alignment: .top, spacing: cardGap) {
            ForEach(0..<3, id: \.self) { i in
                let draws = entry?.reading.draws ?? []
                let drawn = i < draws.count ? draws[i] : nil
                let isUp = faceUp[i]
                VStack(spacing: 6) {
                    RevealCard(card: drawn?.card ?? Arcana.all[0],
                                orientation: drawn?.orientation ?? .upright,
                                faceUp: isUp,
                                reduceMotion: reduceMotion,
                                tilt: tilt,
                                isFaceUp: isUp && live)
                        .frame(width: cardW, height: cardH)
                        .contentShape(Rectangle().inset(by: -5))
                        .onTapGesture { focus = i }
                        // One VoiceOver element per card (the table's rule).
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "\((Spread.threeCards.positions[i].name)) card: \((drawn?.card ?? Arcana.all[0]).name), \(isUp ? (drawn?.orientation.label ?? "") : "face down").")
                        .accessibilityAddTraits(.isButton)

                    Text(Spread.threeCards.positions[i].name)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(focus == i ? 0.85 : 0.45))
                        .lineLimit(1)
                        .frame(maxWidth: cardW)
                        .accessibilityHidden(true)   // the card's own label carries it
                }
            }
        }
    }

    // MARK: The meaning panel (one card at a time, as on the table)

    @ViewBuilder
    private var meaningPanel: some View {
        if let entry, focus < entry.reading.count {
            let drawn = entry.reading.draws[focus]
            let position = Spread.threeCards.positions[focus].name
            VStack(spacing: 8) {
                Text(position)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.45))
                Text(drawn.card.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(drawn.orientation.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(drawn.orientation == .upright ? ReadingTable.uprightInk : ReadingTable.invertedInk)
                Text(drawn.meaning)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(position): \(drawn.card.name), \(drawn.orientation.label). \(drawn.meaning)")
            .accessibilityAddTraits(.isStaticText)
        } else {
            Text("Tap a card to read it again")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.4))
                .accessibilityHidden(true)
        }
    }

    // MARK: Saved reflection and note

    @ViewBuilder
    private var reflectionSection: some View {
        if let reflection = entry?.reflection {
            VStack(alignment: .leading, spacing: 8) {
                Text("Saved reflection")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.45))
                Text(reflection)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noteSection: some View {
        VStack(spacing: 8) {
            Text("Note")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("A note about this day…", text: $noteText)
                .font(.callout)
                .foregroundStyle(.white)
                .tint(ReadingTable.uprightInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                .onSubmit(commitNote)
                .focused($noteFocused)
                .accessibilityLabel("Note for this day")
        }
        // A commit trims in the store; echo the canonical form back into the
        // field (only when it differs, so mid-typing is never clobbered).
        .onChange(of: entry?.note) { _, newValue in
            if let newValue, noteText != newValue {
                noteText = newValue
            }
        }
    }

    private func commitNote() {
        store.setNote(noteText, for: entryID)
        noteFocused = false
    }

    /// A detail is keyed to its entry ID, so this is run once per selected
    /// day. Keeping the reveal state in step with the entry avoids showing
    /// the previous day's cards while SwiftUI reconciles the new selection.
    private func seedStateFromEntry() {
        guard !noteSeeded else { return }
        noteText = entry?.note ?? ""
        noteSeeded = true
        focus = 0
        faceUp = Array(repeating: isActive, count: Spread.threeCards.positions.count)
    }

    /// Under Reduce Motion: a plain crossfade instead of a 3D flip (the
    /// table's vestibular rule, held).
    private var flip: Animation {
        reduceMotion ? .easeInOut(duration: 0.35) : .spring(response: 0.5, dampingFraction: 0.8)
    }
}

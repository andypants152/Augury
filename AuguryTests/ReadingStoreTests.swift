import XCTest
@testable import Augury

/// M8 — `ReadingStore`: the daily journal.
///
/// Done-when (from the roadmap):
///   • drawing three and saving lands an entry dated to the day;
///   • a saved entry survives kill + relaunch and reopens identically
///     (cards, orientations, date, note);
///   • append-only.
/// The free cap of 3 entries is M9's gating, not the store's — uncapped here.
///
/// Every store is pointed at a throwaway directory, so the tests exercise the
/// real file (the persistence *is* the feature) without touching the app's
/// journal. Readings come from the seeded engine (M5's one real random, in
/// its reproducible form) so every save is the same on every run.
final class ReadingStoreTests: XCTestCase {

    let deck = Arcana.all

    // ── helpers ─────────────────────────────────────────────────────────────

    /// A fresh throwaway directory per call — one journal file per test.
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("augury-journal-\(UUID().uuidString)")
    }

    /// A whole-second wall-clock date (iso8601 round-trips it exactly).
    private func makeDate(_ year: Int, _ month: Int, _ day: Int,
                          hour: Int = 14, minute: Int = 30) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    /// A 3-card deal from a seeded engine — deterministic per seed.
    private func deal(seed: UInt64) -> Reading {
        var engine = ReadingEngine(seed: seed)
        return engine.deal(count: 3, from: deck)
    }

    private func card(_ id: ArcanaID) -> Arcana {
        Arcana.all.first { $0.id == id }!
    }

    // ── saving: the daily stamp ─────────────────────────────────────────────

    /// Roadmap bar 1: draw three and save — the entry lands dated to the day,
    /// and the journal lands on the device.
    func testSaveLandsAnEntryDatedToTheDay() {
        let dir = tempDir()
        let store = ReadingStore(directory: dir)
        let date = makeDate(2026, 6, 3, hour: 9, minute: 12)

        let entry = store.save(deal(seed: 0x1), date: date)

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first, entry)
        XCTAssertEqual(entry.date, date, "the entry keeps the save's timestamp")
        XCTAssertEqual(Calendar.current.startOfDay(for: entry.date),
                       Calendar.current.startOfDay(for: date),
                       "the entry is dated to *the day* of the save")
        XCTAssertEqual(entry.reading.count, 3)
        XCTAssertNil(entry.note)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent(ReadingStore.fileName).path),
            "saving must land the journal file on the device")
    }

    /// The default stamp is now — "that day", whatever the clock says.
    func testDefaultSaveStampsToday() {
        let store = ReadingStore(directory: tempDir())
        let entry = store.save(deal(seed: 0x2))
        XCTAssertEqual(Calendar.current.startOfDay(for: entry.date),
                       Calendar.current.startOfDay(for: Date()),
                       "a save now must land in today's bucket")
    }

    /// The journal's unit is the day: two moments of the same clock day
    /// upsert the one entry; the next clock day appends a new one.
    func testOneEntryPerDay_thenAPerDay() {
        let store = ReadingStore(directory: tempDir())
        let noon = makeDate(2026, 6, 3, hour: 12)
        let night = makeDate(2026, 6, 3, hour: 23, minute: 59)
        let nextMorning = makeDate(2026, 6, 4, hour: 1)

        let first = store.save(deal(seed: 0x3), date: noon)
        let resave = store.save(deal(seed: 0x4), date: night)
        XCTAssertEqual(store.entries.count, 1, "same clock day → one entry")
        XCTAssertEqual(resave.id, first.id, "a day's entry keeps its identity")
        XCTAssertEqual(resave.date, noon, "a day's entry keeps its first stamp")

        store.save(deal(seed: 0x5), date: nextMorning)
        XCTAssertEqual(store.entries.count, 2, "the next day appends")
        XCTAssertEqual(store.entries[0].date, noon)
        XCTAssertEqual(store.entries[1].date, nextMorning)
    }

    // ── append-only: the history never moves ────────────────────────────────

    /// Roadmap bar 3. Past days are never rewritten, re-dated, or removed:
    /// the list only grows, and each earlier entry survives later saves
    /// intact.
    func testAppendOnly_pastDaysAreUntouched() {
        let store = ReadingStore(directory: tempDir())
        let day1 = makeDate(2026, 6, 1)
        let day2 = makeDate(2026, 6, 2)
        let day3 = makeDate(2026, 6, 3)

        store.save(deal(seed: 0x11), date: day1)
        let entry1 = store.entries[0]
        store.save(deal(seed: 0x12), date: day2)
        let entry2 = store.entries[1]
        store.save(deal(seed: 0x13), date: day3)

        XCTAssertEqual(store.entries.count, 3)
        XCTAssertEqual(store.entries[0], entry1, "day 1 untouched by later saves")
        XCTAssertEqual(store.entries[1], entry2, "day 2 untouched by day 3")
        XCTAssertEqual(store.entries.map(\.date), [day1, day2, day3],
                       "oldest day first — append order is chronological")
    }

    /// The one-per-day re-save updates that day's *cards* — and preserves
    /// the things a re-save must never touch: the id, the first stamp, the
    /// user's note.
    func testSameDayResaveReplacesCardsKeepsStampAndNote() {
        let store = ReadingStore(directory: tempDir())
        let morning = makeDate(2026, 6, 3, hour: 8)
        let evening = makeDate(2026, 6, 3, hour: 21)

        let first = store.save(deal(seed: 0x21), date: morning)
        store.setNote("Dawn: the star poured.", for: first.id)
        let before = store.entries[0]

        let after = store.save(deal(seed: 0x22), date: evening)

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(after.id, first.id, "same entry — it is *the day's*")
        XCTAssertEqual(after.date, morning, "the day's stamp is the first save's")
        XCTAssertEqual(after.note, "Dawn: the star poured.",
                       "a re-save of the cards must not wipe the user's note")
        XCTAssertNotEqual(after.reading, before.reading, "the cards actually changed")
    }

    // ── kill + relaunch: the file is the memory ─────────────────────────────

    /// Roadmap bar 2, in its testable form: a *second* store instance pointed
    /// at the same directory (what launch does) reloads identical state —
    /// cards, orientations, date, note.
    func testSurvivesRelaunch_secondInstanceReadsTheSameJournal() {
        let dir = tempDir()
        let first = ReadingStore(directory: dir)
        let entry = first.save(deal(seed: 0x31), date: makeDate(2026, 6, 3, hour: 9))
        first.setNote("The cards were blunt.", for: entry.id)

        let relaunched = ReadingStore(directory: dir)
        XCTAssertEqual(relaunched.entries, first.entries,
                       "a relaunch must reopen the journal identically")
    }

    /// The field-by-field form of the same bar (the done-when's wording:
    /// "cards, orientations, date, note") — re-read from the file by a
    /// *third* instance, compared against the original save.
    func testReopensIdentically_everyFieldSurvivesTheFile() {
        let dir = tempDir()
        let first = ReadingStore(directory: dir)
        let entry = first.save(deal(seed: 0x32), date: makeDate(2026, 6, 3, hour: 9, minute: 5))
        first.setNote("  Two spaces, an em dash — verified. ", for: entry.id)
        // The store's live entry is the source of truth for the file (the
        // `entry` returned by `save` predates the note).
        let expected = first.entries[0]

        let fromFile = ReadingStore(directory: dir)
        XCTAssertEqual(fromFile.entries.count, 1)
        let stored = fromFile.entries[0]

        XCTAssertEqual(stored.id, expected.id)
        XCTAssertEqual(stored.date, expected.date)
        XCTAssertEqual(stored.note, expected.note, "setNote trims; the file holds the trimmed form")
        XCTAssertEqual(stored.reading.count, 3)
        for (s, o) in zip(stored.reading.draws, expected.reading.draws) {
            XCTAssertEqual(s.card.id, o.card.id)
            XCTAssertEqual(s.card.name, o.card.name)
            XCTAssertEqual(s.card.keywords, o.card.keywords)
            XCTAssertEqual(s.card.upright, o.card.upright)
            XCTAssertEqual(s.card.inverted, o.card.inverted)
            XCTAssertEqual(s.orientation, o.orientation)
        }
    }

    // ── the note: the one mutable field ─────────────────────────────────────

    func testNoteSetsTrimsAndClears() {
        let dir = tempDir()
        let store = ReadingStore(directory: dir)
        let entry = store.save(deal(seed: 0x41))

        store.setNote("A long day.", for: entry.id)
        store.setNote("  A longer one.  ", for: entry.id)
        XCTAssertEqual(store.entries[0].note, "A longer one.", "whitespace trims")

        store.setNote("   ", for: entry.id)
        XCTAssertNil(store.entries[0].note, "an empty note clears to nil")

        let reread = ReadingStore(directory: dir)
        XCTAssertNil(reread.entries[0].note, "the clearing persists")
    }

    func testExplicitReflectionPersistsAndResaveClearsAStaleReflection() {
        let dir = tempDir()
        let store = ReadingStore(directory: dir)
        let date = makeDate(2026, 6, 3)
        let entry = store.save(deal(seed: 0x42), date: date)

        store.setReflection("  A patient turning point.  ", for: entry.id)
        XCTAssertEqual(store.entries[0].reflection, "A patient turning point.")
        XCTAssertEqual(ReadingStore(directory: dir).entries[0].reflection, "A patient turning point.")

        let replaced = store.save(deal(seed: 0x43), date: date)
        XCTAssertNil(replaced.reflection, "a reflection must not describe replaced cards")
    }

    // ── the file itself ─────────────────────────────────────────────────────

    /// A journal that has never existed is an empty journal, not a crash.
    func testMissingFileStartsEmpty() {
        let store = ReadingStore(directory: tempDir())
        XCTAssertTrue(store.entries.isEmpty)
    }

    /// A corrupt file must not wedge the app, and its bytes must not vanish:
    /// the store quarantines it (a timestamped rename) and starts empty.
    func testCorruptFileIsQuarantinedNotFatal() throws {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(ReadingStore.fileName)
        try Data("this is not a journal".utf8).write(to: file)

        let store = ReadingStore(directory: dir)
        XCTAssertTrue(store.entries.isEmpty, "the app must come up empty, not crash")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path),
                       "the corrupt file is moved, not left to re-fail")
        let quarantined = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix(ReadingStore.fileName) }
        XCTAssertEqual(quarantined.count, 1, "the bytes are kept, renamed with a timestamp")
    }

    /// The wire format: encode → decode is identity (iso8601 dates, a nil
    /// note, both falls, keywords intact). A hand-built entry — this is the
    /// serialization contract, not a store round-trip.
    func testCodableRoundTripIsIdentity() throws {
        let reading = Reading(draws: [
            DrawnCard(card: card(.star), orientation: .upright),
            DrawnCard(card: card(.moon), orientation: .inverted),
        ])
        let entry = JournalEntry(date: makeDate(2026, 6, 3, hour: 10, minute: 0),
                                 reading: reading,
                                 note: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([entry])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode([JournalEntry].self, from: data)

        XCTAssertEqual(back, [entry], "the JSON is lossless")
    }
}

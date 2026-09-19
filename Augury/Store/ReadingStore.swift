import Foundation
import Combine

// MARK: - JournalEntry

/// One day's entry in the daily journal (M8).
///
/// A saved reading, dated to the day it was saved, with an optional note the
/// user adds afterward: the cards + how each fell + the day + the note.
///
/// The entry is deliberately **self-contained**: it stores the full `Arcana`
/// (name, keywords, both meanings) rather than just an id. The deck is made
/// once, done, so the stored words can never drift from the catalog — but a
/// past entry also renders identically even if the catalog's *format* ever
/// changes. "Reopens identically" (cards, orientations, date, note) falls
/// out of a deep value equality, which is what the tests pin.
struct JournalEntry: Identifiable, Hashable, Codable {
    /// Stable identity — the note's target, the list's row id.
    let id: UUID

    /// When the day's entry was **first** saved (the day stamp). A same-day
    /// re-save keeps the original stamp — a day's entry is dated once.
    let date: Date

    /// The draws, in deal order — the order is the position (Past / Present /
    /// Future). The v1 journal is the 3-card ritual; the entry stores a
    /// `Reading`, so the store itself stays general.
    let reading: Reading

    /// The user's own words about the day — the one mutable field.
    var note: String?

    init(id: UUID = UUID(),
         date: Date = Date(),
         reading: Reading,
         note: String? = nil) {
        self.id = id
        self.date = date
        self.reading = reading
        self.note = note
    }
}

// MARK: - ReadingStore

/// The daily journal (roadmap M8): a small, local log of saved readings,
/// one per calendar day.
///
/// **The semantics** (the load-bearing part — pinned in `ReadingStoreTests`):
///
/// - **One entry per day.** `save` upserts *that day*: a first save for a
///   day appends the day's entry; a later save the same day replaces that
///   day's cards, keeping the entry's identity, its first-saved stamp, and
///   the user's note. Every *earlier* day is untouched.
/// - **Append-only.** Past days are never rewritten, re-dated, or removed —
///   there is no delete, by design. The only field-level mutation the
///   journal allows is the note (`setNote`).
/// - **Local JSON, offline.** The journal lives on the device (Application
///   Support), in one file — the no-account / no-network promise. Writes are
///   atomic; a corrupt file is quarantined with a timestamp, never silently
///   destroyed, and never wedges the app.
///
/// The store is **uncapped on purpose**: the free tier's "3 entries" gate is
/// content gating — M9 applies it *above* the store, not inside it (roadmap
/// "Where we are": "the free cap of 3 entries is M9's gating, not the
/// store's").
///
/// A main-queue UI object (as `MotionTilt` is): create it once, mutate it
/// from the main actor.
final class ReadingStore: ObservableObject {

    /// The entries, oldest day first — append order is chronological order.
    @Published private(set) var entries: [JournalEntry]

    /// The calendar that resolves "the day" — injected for tests.
    private let calendar: Calendar

    private let fileURL: URL
    private let fileManager: FileManager

    /// The journal's one file: `<Application Support>/journal.json`.
    /// (Application Support, not Documents: a private journal shouldn't
    /// clutter the Files app.)
    static let fileName = "journal.json"

    /// `nil` → the app's Application Support directory.
    init(directory: URL? = nil,
         calendar: Calendar = .current,
         fileManager: FileManager = .default) {
        self.calendar = calendar
        self.fileManager = fileManager
        let dir = directory ?? Self.defaultDirectory(fileManager: fileManager)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(Self.fileName)
        self.entries = Self.load(from: fileURL, fileManager: fileManager)
    }

    static func defaultDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    // MARK: Saving

    /// Save a reading as that day's entry (roadmap M8: "draw three and save
    /// them as today's entry (date-stamped)").
    ///
    /// The day is the calendar day of `date` (default: now). First save for
    /// a day → a new entry, appended. A same-day re-save → that day's entry
    /// is updated in place: new cards, same id, same first-saved stamp, and
    /// the user's note is **preserved** (a re-save of the cards must never
    /// wipe the user's words). Past days are never touched. Returns the
    /// entry now on file for that day; the journal is persisted either way.
    @discardableResult
    func save(_ reading: Reading, date: Date = Date()) -> JournalEntry {
        let day = calendar.startOfDay(for: date)
        let entry: JournalEntry
        if let i = entries.firstIndex(where: { calendar.startOfDay(for: $0.date) == day }) {
            let existing = entries[i]
            entry = JournalEntry(id: existing.id,
                                 date: existing.date,
                                 reading: reading,
                                 note: existing.note)
            entries[i] = entry
        } else {
            entry = JournalEntry(date: date, reading: reading)
            entries.append(entry)
        }
        persist()
        return entry
    }

    /// The user's note for an entry — set, or cleared (empty/whitespace →
    /// `nil`). The only field-level mutation the journal allows.
    func setNote(_ text: String?, for id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[i].note = (trimmed?.isEmpty == false) ? trimmed : nil
        persist()
    }

    // MARK: Queries

    /// The entry for a given day, if any — the table's "is today already
    /// journaled?" query.
    func entry(forDay date: Date) -> JournalEntry? {
        let day = calendar.startOfDay(for: date)
        return entries.last { calendar.startOfDay(for: $0.date) == day }
    }

    func entry(for id: UUID) -> JournalEntry? {
        entries.first { $0.id == id }
    }

    // MARK: Persistence

    /// Write the journal to disk — atomically (temp file + replace), so a
    /// half-written file is never what a relaunch reads.
    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // A write failure (disk full, etc.) is not fatal: the in-memory
            // journal keeps working, and the next mutation retries the write.
        }
    }

    /// Load the journal at startup (the "survives kill + relaunch" half of
    /// M8: the store's init is the only thing that re-reads the file).
    ///
    /// Missing file → an empty journal. Unreadable/unparseable file →
    /// quarantined (renamed `journal.json.corrupt-<unixtime>`) and an empty
    /// journal — a corrupt file must never wedge the app, and the bytes must
    /// never be silently destroyed.
    private static func load(from fileURL: URL, fileManager: FileManager) -> [JournalEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([JournalEntry].self, from: data)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let quarantined = fileURL.deletingPathExtension()
                .appendingPathExtension("json.corrupt-\(stamp)")
            try? fileManager.moveItem(at: fileURL, to: quarantined)
            return []
        }
    }
}

import SwiftUI

/// The app root: the reading table (M6), spread-driven (M7).
///
/// M4's one-card shell was retired in M6: its card components (`RevealCard`,
/// `CardFace`, `CardBack`, `FlipCard`) moved to `UI/Card.swift` unchanged,
/// and its deal flows through the `Reading` engine (M5) — the one real
/// "random" in the app. M7 makes the table spread-driven — one card, three,
/// or the Celtic cross (`Models/Spread.swift` + `UI/SpreadLayout.swift`);
/// M8 adds the journal.
struct ContentView: View {
    var body: some View {
        ReadingTable()
    }
}

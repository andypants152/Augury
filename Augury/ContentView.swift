import SwiftUI

/// The app root: the three-card reading table (M6).
///
/// M4's one-card shell is retired here: its card components (`RevealCard`,
/// `CardFace`, `CardBack`, `FlipCard`) moved to `UI/Card.swift` unchanged,
/// and its deal now flows through the `Reading` engine (M5) — the one real
/// "random" in the app. M7 will add the other spreads; M8 the journal.
struct ContentView: View {
    var body: some View {
        ReadingTable()
    }
}

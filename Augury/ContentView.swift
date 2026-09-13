import SwiftUI

/// M3 shell — browse the deck. The real table / draw / flip / reveal UI lands in M6.
///
/// Each card's art ships as two layers in the asset catalog: the shared `card-bg`
/// gradient plus the card's transparent line-art layer, both canonical SVGs that
/// `actool` rasterizes at 3x (the sparse art layers keep the whole deck around
/// 8 MB in the compiled catalog instead of ~130 MB). See `tools/card-draft`
/// for how the deck is made.
struct ContentView: View {
    @State private var index = 0

    private let cards = Arcana.all

    var body: some View {
        let card = cards[index]
        ZStack {
            Color.black
            CardFace(arcana: card)
                .padding(12)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .accessibilityLabel("\(card.name), tap for another card")
    }

    private func advance() {
        var next = Int.random(in: cards.indices)
        if next == index { next = (next + 1) % cards.count }
        index = next
    }
}

/// One face-up card: the shared `card-bg` with this card's line-art layer on top.
///
/// The art is an `.overlay` of the background (not a `ZStack` of two resizable
/// images): an overlay is proposed the exact size of the view it modifies, so
/// the two layers are always the same size and aligned. The 9:16 ratio is applied
/// to the background image itself — applying it to a `ZStack` of two fully-
/// flexible `.resizable()` images is ambiguous and distorts the card.
struct CardFace: View {
    let arcana: Arcana

    private static let cardRatio = 540.0 / 960.0   // the draft canvas, 9:16

    var body: some View {
        Image("card-bg")
            .resizable()
            .aspectRatio(Self.cardRatio, contentMode: .fit)
            .overlay(
                Image(arcana.assetName)
                    .resizable()
            )
    }
}

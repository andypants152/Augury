import SwiftUI

/// A quiet reference room for the permanent deck. It is intentionally static:
/// cards do not deal, flip, or start the motion sensor here. The entitlement
/// supplies the exact cards the reader may browse, just as it supplies the
/// deck the reading engine shuffles.
struct CardLibraryView: View {
    @EnvironmentObject private var purchase: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Arcana?
    @State private var showingPaywall = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var cards: [Arcana] { purchase.entitlement.deck }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        intro

                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(cards) { card in
                                Button { selected = card } label: {
                                    VStack(spacing: 7) {
                                        LibraryCardImage(card: card)
                                        Text(card.name)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(card.name), view card meanings")
                            }
                        }

                        if !purchase.entitlement.isFull {
                            unlockRow
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Card library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ReadingTable.uprightInk)
                }
            }
            .navigationDestination(item: $selected) { card in
                CardLibraryDetail(card: card)
            }
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            Paywall(purchase: purchase) { showingPaywall = false }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(purchase.entitlement.isFull ? "All 78 cards" : "The 22 Major Arcana")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(purchase.entitlement.isFull
                 ? "A permanent reference for the whole Augury deck."
                 : "A complete archetypal deck for reflection and study.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .accessibilityElement(children: .combine)
    }

    private var unlockRow: some View {
        Button { showingPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundStyle(ReadingTable.uprightInk)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explore all 78 cards")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Unlock the four minor suits and the full reference deck.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ReadingTable.uprightInk.opacity(0.25)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Explore all 78 cards by unlocking the full deck")
    }
}

private struct CardLibraryDetail: View {
    let card: Arcana

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        LibraryCardImage(card: card)
                            .frame(width: 176)
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        Text(card.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(card.keywords.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(ReadingTable.uprightInk)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    meaning(title: "Upright", text: card.upright, tint: ReadingTable.uprightInk)
                    meaning(title: "Inverted", text: card.inverted, tint: ReadingTable.invertedInk)
                }
                .padding(22)
            }
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func meaning(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(tint)
            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Static card art for the library. It preserves the card face's two-layer
/// overlay composition but deliberately omits the live holographic finish.
private struct LibraryCardImage: View {
    let card: Arcana

    var body: some View {
        Image("card-bg")
            .resizable()
            .aspectRatio(CardFace.cardRatio, contentMode: .fit)
            .overlay(Image(card.assetName).resizable())
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.16)))
            .accessibilityHidden(true)
    }
}

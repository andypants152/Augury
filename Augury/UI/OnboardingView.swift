import SwiftUI

/// The first visit to Augury: a short, skippable orientation before the
/// table begins. It explains the ritual without asking for data, permission,
/// or a purchase, and is intentionally shown only once by `ContentView`.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages = [
        OnboardingPage(
            symbol: "sparkles",
            title: "A quiet place to reflect",
            body: "Augury offers a moment with the cards—not a prediction or instruction. Let the images and meanings prompt your own perspective."
        ),
        OnboardingPage(
            symbol: "arrow.triangle.2.circlepath",
            title: "Every card has two voices",
            body: "Cards may fall upright or inverted. Neither is good or bad; each offers a different angle on the same symbol. Reveal them one at a time and linger where it feels useful."
        ),
        OnboardingPage(
            symbol: "book.closed",
            title: "Make a small ritual of it",
            body: "Choose a one-card or three-card reading, then save a completed three-card spread and a note in your private, on-device journal. The free deck includes all 22 Major Arcana; one purchase adds the full 78, the Celtic cross, and unlimited journal days."
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button("Skip", action: onFinish)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(12)
                        .accessibilityLabel("Skip introduction and begin a reading")
                }
                .padding(.horizontal, 14)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        page(item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .accessibilityLabel("Introduction, page \(page + 1) of \(pages.count)")

                Button(action: advance) {
                    Text(page == pages.count - 1 ? "Begin reading" : "Continue")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.02))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ReadingTable.uprightInk, in: Capsule())
                }
                .accessibilityLabel(page == pages.count - 1 ? "Begin a reading" : "Continue to the next introduction page")
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .interactiveDismissDisabled()
    }

    private func page(_ item: OnboardingPage) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: item.symbol)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(ReadingTable.uprightInk)
                    .frame(height: 72)
                    .accessibilityHidden(true)

                Text(item.title)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(item.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, minHeight: 360)
        }
        .accessibilityElement(children: .combine)
    }

    private func advance() {
        if page == pages.count - 1 {
            onFinish()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                page += 1
            }
        }
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let body: String
}

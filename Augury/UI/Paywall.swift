import SwiftUI

/// The paywall (roadmap M9): the one honest unlock, stated plainly.
///
/// A full-screen room in the house's own dark idiom (custom chrome, no
/// system bar): what the unlock is, the **one-time price**, the buy, the
/// restore. It is presented by the table and the journal when a free user
/// meets a gate — the unlock affordance, or the journal's 3-day cap — and
/// dismisses itself the moment the entitlement lands.
///
/// The price is the store's own (`product.displayPrice`) once it has loaded,
/// and the documented intent (`PurchaseManager.intendedPrice`, $0.99) until
/// then — so it states the one-time price plainly either way, and is always
/// the real price.
struct Paywall: View {
    @Environment(\.dismiss) private var dismiss

    /// The purchase flow — buy and restore act on it; the entitlement it
    /// publishes is what dismisses this view.
    let purchase: PurchaseManager
    /// The presenting room's own flag, kept in step with `dismiss`.
    var onDismiss: () -> Void = {}

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 26) {
                // The close — the ritual resumes exactly where it left off.
                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                VStack(spacing: 6) {
                    Text("The full deck")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("One purchase. Yours forever.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                }

                includes

                priceBlock

                buyButton

                if purchase.purchaseFailed {
                    Text("The purchase didn't complete — try again.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await restore() }
                } label: {
                    Text("Restore purchase")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .disabled(purchase.isPurchasing)
                .accessibilityLabel("Restore a purchase made on another device or a previous install")

                Text("No subscription. No account. Your journal stays on your device.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .contain)
        // The moment the entitlement lands, the paywall's job is done.
        .onChange(of: purchase.entitlement) { _, entitlement in
            if entitlement.isFull { close() }
        }
    }

    // MARK: What the unlock is

    private var includes: some View {
        VStack(spacing: 16) {
            item(icon: "sparkles",
                 title: "All 78 cards",
                 detail: "the 56 minors join the 22 majors")
            item(icon: "plus",
                 title: "The Celtic cross",
                 detail: "the classic ten")
            item(icon: "book",
                 title: "Unlimited journal",
                 detail: "every day you keep")
        }
        .accessibilityElement(children: .combine)
    }

    private func item(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(ReadingTable.uprightInk)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: The price

    private var priceBlock: some View {
        VStack(spacing: 4) {
            Text(purchase.displayPrice)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(ReadingTable.uprightInk)
            Text("one time — yours forever")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(purchase.displayPrice), one time, yours forever")
    }

    // MARK: The buy

    private var buyButton: some View {
        Button {
            Task { await buy() }
        } label: {
            Group {
                if purchase.isPurchasing {
                    ProgressView()
                        .tint(Color(red: 0.10, green: 0.08, blue: 0.02))
                } else {
                    Text("Unlock Augury")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.02))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ReadingTable.uprightInk, in: Capsule())
        }
        .disabled(purchase.isPurchasing)
        .accessibilityLabel("Unlock Augury for \(purchase.displayPrice), one time")
    }

    private func buy() async {
        _ = await purchase.purchase()
        if purchase.entitlement.isFull { close() }
    }

    private func restore() async {
        await purchase.restore()
        if purchase.entitlement.isFull { close() }
    }

    private func close() {
        onDismiss()
        dismiss()
    }
}

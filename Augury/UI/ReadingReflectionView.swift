import SwiftUI
import UIKit

/// The private, generated reflection for a completed spread. It is presented
/// above the table so the cards remain the source of the reading, not the
/// generated text.
struct ReadingReflectionView: View {
    @EnvironmentObject private var store: ReadingStore
    let reading: Reading
    let spread: Spread
    @ObservedObject var interpreter: ReadingInterpreter
    let onDismiss: () -> Void
    @State private var copied = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
                    .padding(22)
            }
            .navigationTitle("Your reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(ReadingTable.uprightInk)
                }
            }
        }
        .task { interpreter.interpret(reading, in: spread) }
    }

    @ViewBuilder
    private var content: some View {
        switch interpreter.state {
        case .idle, .loading:
            VStack(spacing: 14) {
                ProgressView().tint(ReadingTable.uprightInk)
                Text("Considering the cards…")
                    .foregroundStyle(.white.opacity(0.75))
                Text("Generated privately on your device")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.45))
            }
        case .complete(let reflection):
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(reflection)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("A reflection, not a prediction.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.45))
                    actions(reflection)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .unavailable(let message), .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(ReadingTable.uprightInk)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                Button("Try again") { interpreter.interpret(reading, in: spread) }
                    .buttonStyle(.bordered)
                    .tint(ReadingTable.uprightInk)
            }
        }
    }

    @ViewBuilder
    private func actions(_ reflection: String) -> some View {
        HStack(spacing: 14) {
            Button {
                UIPasteboard.general.string = shareText(reflection)
                copied = true
            } label: { Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") }
            ShareLink(item: shareText(reflection)) { Label("Share", systemImage: "square.and.arrow.up") }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(ReadingTable.uprightInk)

        if spread.id == Spread.threeCards.id {
            if let entry = store.entry(forDay: Date()), entry.reading == reading {
                Button {
                    store.setReflection(reflection, for: entry.id)
                    saved = true
                } label: {
                    Label(saved || entry.reflection == reflection ? "Saved to journal" : "Save to journal",
                          systemImage: saved || entry.reflection == reflection ? "checkmark" : "bookmark")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("Save this three-card reading to your journal before keeping its reflection.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func shareText(_ reflection: String) -> String {
        let cards = zip(spread.positions, reading.draws)
            .map { "\($0.name): \($1.card.name) (\($1.orientation.label))" }
            .joined(separator: "\n")
        return "Augury reflection\n\n\(cards)\n\n\(reflection)"
    }
}

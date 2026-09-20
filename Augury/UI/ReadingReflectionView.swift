import SwiftUI

/// The private, generated reflection for a completed spread. It is presented
/// above the table so the cards remain the source of the reading, not the
/// generated text.
struct ReadingReflectionView: View {
    let reading: Reading
    let spread: Spread
    @ObservedObject var interpreter: ReadingInterpreter
    let onDismiss: () -> Void

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
}

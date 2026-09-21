import SwiftUI
import UIKit

/// The journal's non-persistent, on-device look back over the last week.
struct WeeklyReadingView: View {
    let entries: [JournalEntry]
    @ObservedObject var interpreter: WeeklyReadingInterpreter
    let onDismiss: () -> Void
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content.padding(22)
            }
            .navigationTitle("Weekly reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(ReadingTable.uprightInk)
                }
            }
        }
        .task { interpreter.interpret(entries) }
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "book")
                    .font(.title)
                    .foregroundStyle(ReadingTable.uprightInk)
                Text("No readings from the past seven days yet.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Save a three-card reading and its note to begin your weekly reflection.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.45))
            }
        } else {
            switch interpreter.state {
            case .idle, .loading:
                VStack(spacing: 14) {
                    ProgressView().tint(ReadingTable.uprightInk)
                    Text("Considering your week…").foregroundStyle(.white.opacity(0.75))
                    Text("Generated privately on your device")
                        .font(.footnote).foregroundStyle(.white.opacity(0.45))
                }
            case .complete(let reflection):
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(reflection).font(.body).foregroundStyle(.white.opacity(0.9))
                        Text("A reflection, not a prediction or a journal record.")
                            .font(.footnote).foregroundStyle(.white.opacity(0.45))
                        HStack(spacing: 14) {
                            Button {
                                UIPasteboard.general.string = reflection
                                copied = true
                            } label: { Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") }
                            ShareLink(item: reflection) { Label("Share", systemImage: "square.and.arrow.up") }
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(ReadingTable.uprightInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .unavailable(let message), .failed(let message):
                VStack(spacing: 14) {
                    Image(systemName: "sparkles").font(.title).foregroundStyle(ReadingTable.uprightInk)
                    Text(message).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
                    Button("Try again") { interpreter.interpret(entries) }
                        .buttonStyle(.bordered).tint(ReadingTable.uprightInk)
                }
            }
        }
    }
}

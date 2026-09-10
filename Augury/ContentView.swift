import SwiftUI

/// Placeholder shell. The real table / draw / reveal UI lands in M6.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Augury")
                .font(.largeTitle.bold())
            Text("The deck is being built — \(Arcana.all.count) of 78 cards so far.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .foregroundStyle(.white)
    }
}

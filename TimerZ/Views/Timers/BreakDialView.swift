import SwiftUI

struct BreakDialView: View {
    let maxMinutes: Int
    let onStart: (Int) -> Void

    @State private var selectedMinutes: Int

    init(maxMinutes: Int, onStart: @escaping (Int) -> Void) {
        self.maxMinutes = maxMinutes
        self.onStart = onStart
        _selectedMinutes = State(initialValue: max(1, min(maxMinutes, 5)))
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Spend Banked Time")
                .font(.headline)

            JogDial(minutes: $selectedMinutes, range: 1...max(1, maxMinutes))
                .frame(width: 240, height: 240)

            Button("Start Break") {
                onStart(selectedMinutes)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .controlSize(.large)
        }
        .padding()
    }
}

import SwiftUI

private struct ActiveTimer: Identifiable {
    let id = UUID()
    let seconds: Int
}

struct TimersView: View {
    @AppStorage(Keys.timerPresets) private var presetsString: String = "5,10,15,25"

    @State private var activeTimer: ActiveTimer?

    private var presets: [Int] {
        presetsString
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(presets, id: \.self) { minutes in
                        Button {
                            activeTimer = ActiveTimer(seconds: minutes * 60)
                        } label: {
                            Text("\(minutes) min")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.75)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("TimerZ")
        }
        .fullScreenCover(item: $activeTimer) { timer in
            TimerSessionView(durationSeconds: timer.seconds) {
                activeTimer = nil
            }
        }
    }
}

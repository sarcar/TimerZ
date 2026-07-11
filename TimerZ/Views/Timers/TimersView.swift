import SwiftUI

struct TimersView: View {
    @AppStorage(Keys.timerPresets) private var presetsString: String = "5,10,15,25"

    @State private var isShowingTimer = false
    @State private var selectedSeconds = 0

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
                            selectedSeconds = minutes * 60
                            isShowingTimer = true
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
        .fullScreenCover(isPresented: $isShowingTimer) {
            TimerSessionView(durationSeconds: selectedSeconds) {
                isShowingTimer = false
            }
        }
    }
}

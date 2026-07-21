import SwiftUI
import SwiftData

private struct ActiveTimer: Identifiable {
    let id = UUID()
    let seconds: Int
    let isTest: Bool
    let isCountUp: Bool
}

struct TimersView: View {
    @AppStorage(Keys.timerPresets) private var presetsString: String = "5,10,15,25"
    @Environment(AppState.self) private var appState
    @Query(sort: \Session.completedAt, order: .reverse) private var sessions: [Session]

    @State private var activeTimer: ActiveTimer?
    @State private var showAmendSheet = false

    private var lastSession: Session? { sessions.first }

    private var presets: [Int] {
        presetsString
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("TimerZ")
                        .font(.largeTitle.bold())
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    LazyVGrid(columns: columns, spacing: 16) {
                        if appState.testModeEnabled {
                            timerButton(
                                label: { AnyView(testButtonLabel) },
                                seconds: 3,
                                color: .orange,
                                isTest: true
                            )
                        }
                        ForEach(presets, id: \.self) { minutes in
                            timerButton(
                                label: { AnyView(Text("\(minutes) min")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))) },
                                seconds: minutes * 60,
                                color: .blue,
                                isTest: false
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $activeTimer) { timer in
            TimerSessionView(
                durationSeconds: timer.seconds,
                isTest: timer.isTest,
                isCountUp: timer.isCountUp,
                onDismiss: {
                    activeTimer = nil
                },
                onDismissAndAmend: {
                    activeTimer = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        showAmendSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showAmendSheet) {
            if let session = lastSession {
                AmendSessionSheet(session: session)
            }
        }
    }

    private var testButtonLabel: some View {
        VStack(spacing: 2) {
            Text("Test")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text("3 sec")
                .font(.system(size: 28, weight: .bold, design: .rounded))
        }
    }

    private func timerButton(
        label: () -> AnyView,
        seconds: Int,
        color: Color,
        isTest: Bool
    ) -> some View {
        let tap = TapGesture().onEnded {
            activeTimer = ActiveTimer(seconds: seconds, isTest: isTest, isCountUp: false)
        }
        let longPress = LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            activeTimer = ActiveTimer(seconds: seconds, isTest: isTest, isCountUp: true)
        }

        return label()
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .gesture(longPress.exclusively(before: tap))
    }
}

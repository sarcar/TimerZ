import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import AudioToolbox

struct TimerSessionView: View {
    let durationSeconds: Int
    let isTest: Bool
    let onDismiss: @MainActor () -> Void
    let onDismissAndAmend: (@MainActor () -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Keys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(Keys.soundEnabled) private var soundEnabled = true
    @AppStorage(Keys.notificationsEnabled) private var notificationsEnabled = true

    @State private var secondsRemaining: Int
    @State private var sessionState: SessionState = .running
    @State private var showCancelAlert = false
    @State private var timerStartDate = Date()

    enum SessionState { case running, won, lost }

    init(
        durationSeconds: Int,
        isTest: Bool = false,
        onDismiss: @escaping @MainActor () -> Void,
        onDismissAndAmend: (@MainActor () -> Void)? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.isTest = isTest
        self.onDismiss = onDismiss
        self.onDismissAndAmend = onDismissAndAmend
        _secondsRemaining = State(initialValue: durationSeconds)
    }

    private var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var backgroundColor: Color {
        switch sessionState {
        case .running: .clear
        case .won:     .green.opacity(0.08)
        case .lost:    .red.opacity(0.08)
        }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Cancel button row
                HStack {
                    if sessionState == .running {
                        Button {
                            showCancelAlert = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                    Spacer()
                }

                Spacer()

                // Duration label
                Text(durationSeconds < 60 ? "\(durationSeconds) sec session" : "\(durationSeconds / 60) min session")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                // Countdown
                Text(timeString)
                    .font(.system(size: 88, weight: .bold, design: .monospaced))
                    .foregroundStyle(sessionState == .lost ? .red : .primary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: secondsRemaining)
                    .padding(.bottom, 48)

                // Action area
                Group {
                    switch sessionState {
                    case .running:
                        checkmarkButton
                    case .won:
                        wonView
                    case .lost:
                        lostView
                    }
                }
                .animation(.spring(duration: 0.4), value: sessionState)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            timerStartDate = Date()
            if notificationsEnabled && !isTest {
                scheduleNotification()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard sessionState == .running else { return }
            let elapsed = Int(Date().timeIntervalSince(timerStartDate))
            let remaining = max(0, durationSeconds - elapsed)
            withAnimation { secondsRemaining = remaining }
            if remaining == 0 { lose() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, sessionState == .running else { return }
            let elapsed = Int(Date().timeIntervalSince(timerStartDate))
            let remaining = max(0, durationSeconds - elapsed)
            secondsRemaining = remaining
            if remaining == 0 { lose() }
        }
        .alert("Cancel session?", isPresented: $showCancelAlert) {
            Button("Keep Going", role: .cancel) {}
            Button("Cancel Session", role: .destructive) {
                cancelNotification()
                onDismiss()
            }
        } message: {
            Text("This session won't be saved.")
        }
    }

    // MARK: - Sub-views

    private var checkmarkButton: some View {
        Button {
            win()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 130, height: 130)
                .background(Color.green)
                .clipShape(Circle())
                .shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel("Complete")
    }

    private var wonView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.green)
            Text("You did it!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var lostView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.red)
            Text("Time's up!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            VStack(spacing: 6) {
                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .padding(.top, 8)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                        onDismissAndAmend?()
                    }
                )
                if onDismissAndAmend != nil {
                    Text("Hold to amend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Actions

    private func win() {
        guard sessionState == .running else { return }
        withAnimation(.spring(duration: 0.4)) { sessionState = .won }
        cancelNotification()
        saveSession(isWin: true)
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            onDismiss()
        }
    }

    private func lose() {
        guard sessionState == .running else { return }
        withAnimation(.spring(duration: 0.4)) { sessionState = .lost }
        cancelNotification()
        saveSession(isWin: false)
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        if soundEnabled {
            Task {
                for _ in 0..<3 {
                    AudioServicesPlayAlertSound(1107)
                    try? await Task.sleep(for: .milliseconds(800))
                }
            }
        }
    }

    private func saveSession(isWin: Bool) {
        guard !isTest else { return }
        let session = Session(durationSeconds: durationSeconds, isWin: isWin)
        modelContext.insert(session)
        try? modelContext.save()
    }

    private func scheduleNotification() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard granted else { return }

                let content = UNMutableNotificationContent()
                content.title = "Time's up!"
                content.body = "Your \(durationSeconds / 60)-min session has ended."
                content.sound = soundEnabled ? .default : nil

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: TimeInterval(durationSeconds),
                    repeats: false
                )
                try await center.add(
                    UNNotificationRequest(identifier: "timerz.expiry", content: content, trigger: trigger)
                )
            } catch {}
        }
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["timerz.expiry"])
    }
}

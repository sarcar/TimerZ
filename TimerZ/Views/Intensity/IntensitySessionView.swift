import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import AVFoundation

struct IntensitySessionView: View {
    let committedUntil: Date
    let isTest: Bool
    let onDismiss: @MainActor () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @AppStorage(Keys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(Keys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(Keys.verbalCountdownEnabled) private var verbalCountdownEnabled = true

    @State private var durationSeconds: Int
    @State private var secondsRemaining: Int
    @State private var secondsElapsed = 0
    @State private var isCountUp = false
    @State private var sessionState: SessionState = .running
    @State private var showQuitDialog = false
    @State private var timerStartDate: Date
    @State private var pendingAnnouncements: [Int] = []
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var sessionVerbalCountdownEnabled = true
    @State private var distractionCount = 0

    enum SessionState { case running, completed, broken }

    init(committedUntil: Date, isTest: Bool = false, onDismiss: @escaping @MainActor () -> Void) {
        self.committedUntil = committedUntil
        self.isTest = isTest
        self.onDismiss = onDismiss
        let now = Date()
        let initialDuration = max(1, Int(committedUntil.timeIntervalSince(now).rounded()))
        _durationSeconds = State(initialValue: initialDuration)
        _secondsRemaining = State(initialValue: initialDuration)
        _timerStartDate = State(initialValue: now)
    }

    private var displaySeconds: Int { isCountUp ? secondsElapsed : secondsRemaining }

    private var timeString: String {
        let m = displaySeconds / 60
        let s = displaySeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var focusUntilString: String {
        committedUntil.formatted(date: .omitted, time: .shortened)
    }

    private var progress: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, Double(secondsElapsed) / Double(durationSeconds))
    }

    private var ringColor: Color {
        switch sessionState {
        case .running: .indigo
        case .completed: .green
        case .broken: .red
        }
    }

    private var announcementThresholds: [Int] {
        var thresholds: [Int] = []
        if durationSeconds > 300 {
            var mark = (durationSeconds - 1) / 300 * 300
            while mark >= 300 {
                thresholds.append(mark)
                mark -= 300
            }
        }
        thresholds.append(contentsOf: [60, 30, 10, 5].filter { $0 < durationSeconds })
        return thresholds
    }

    private var backgroundColor: Color {
        switch sessionState {
        case .running: .clear
        case .completed: .green.opacity(0.08)
        case .broken: .red.opacity(0.08)
        }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: quit + distraction log
                HStack {
                    if sessionState == .running {
                        Button {
                            showQuitDialog = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                    Spacer()
                    if sessionState == .running {
                        distractionControl
                    }
                }

                Spacer()

                // Focus-until label
                HStack(spacing: 6) {
                    if sessionState == .running {
                        Button {
                            sessionVerbalCountdownEnabled.toggle()
                        } label: {
                            Image(systemName: sessionVerbalCountdownEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel(sessionVerbalCountdownEnabled ? "Verbal countdown on. Tap to mute." : "Verbal countdown muted. Tap to unmute.")
                    }
                    Text("Focus until \(focusUntilString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if sessionState == .running {
                        Button {
                            isCountUp.toggle()
                        } label: {
                            Image(systemName: isCountUp ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel(isCountUp ? "Counting up. Tap to count down." : "Counting down. Tap to count up.")
                    }
                }
                .padding(.bottom, 24)

                // Countdown with progress ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    Text(timeString)
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .foregroundStyle(sessionState == .broken ? .red : .primary)
                        .contentTransition(.numericText(countsDown: !isCountUp))
                        .animation(.default, value: displaySeconds)
                }
                .frame(width: 260, height: 260)
                .padding(.bottom, 48)

                // Action area
                Group {
                    switch sessionState {
                    case .running:
                        runningFooter
                    case .completed:
                        completedView
                    case .broken:
                        brokenView
                    }
                }
                .animation(.spring(duration: 0.4), value: sessionState)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            sessionVerbalCountdownEnabled = verbalCountdownEnabled
            pendingAnnouncements = announcementThresholds
            if notificationsEnabled && !isTest {
                scheduleNotification()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard sessionState == .running else { return }
            tick(speak: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, sessionState == .running else { return }
            tick(speak: false)
        }
        .confirmationDialog("Leave this session?", isPresented: $showQuitDialog, titleVisibility: .visible) {
            Button("Leave (will be logged)", role: .destructive) {
                quit(discard: false)
            }
            if appState.testModeEnabled {
                Button("Dev Mode Breakglass", role: .destructive) {
                    quit(discard: true)
                }
            }
            Button("Go back into timer") {}
        } message: {
            Text("You committed to undistracted focus until \(focusUntilString).")
        }
    }

    // MARK: - Sub-views

    private var distractionControl: some View {
        VStack(spacing: 2) {
            Image(systemName: "flag.fill")
                .font(.title2)
                .foregroundStyle(distractionCount > 0 ? .orange : .secondary)
            if distractionCount > 0 {
                Text("\(distractionCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .contentShape(Rectangle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                logDistraction()
            }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Log distraction")
        .accessibilityHint("Double tap and hold")
    }

    private var runningFooter: some View {
        Text("Stay the course.")
            .font(.subheadline)
            .foregroundStyle(.secondary.opacity(0.6))
            .frame(height: 130)
    }

    private var completedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 88))
                .foregroundStyle(.green)
            Text("Commitment kept.")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            if distractionCount > 0 {
                Text("\(distractionCount) distraction\(distractionCount == 1 ? "" : "s") logged along the way.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var brokenView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.seal.fill")
                .font(.system(size: 88))
                .foregroundStyle(.red)
            Text("Commitment broken.")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            if distractionCount > 0 {
                Text("\(distractionCount) distraction\(distractionCount == 1 ? "" : "s") logged.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Actions

    private func tick(speak: Bool) {
        let elapsed = Int(Date().timeIntervalSince(timerStartDate))
        let remaining = max(0, durationSeconds - elapsed)
        withAnimation {
            secondsElapsed = min(elapsed, durationSeconds)
            secondsRemaining = remaining
        }
        consumeAnnouncements(remaining: remaining, speak: speak)
        if remaining == 0 { complete() }
    }

    private func logDistraction() {
        guard sessionState == .running else { return }
        distractionCount += 1
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func complete() {
        guard sessionState == .running else { return }
        withAnimation(.spring(duration: 0.4)) { sessionState = .completed }
        cancelNotification()
        stopAnnouncements()
        saveSession(completed: true, timeSpentSeconds: durationSeconds)
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            onDismiss()
        }
    }

    private func quit(discard: Bool) {
        guard sessionState == .running else { return }
        cancelNotification()
        stopAnnouncements()
        if discard {
            onDismiss()
            return
        }
        let elapsed = Int(Date().timeIntervalSince(timerStartDate))
        withAnimation(.spring(duration: 0.4)) { sessionState = .broken }
        saveSession(completed: false, timeSpentSeconds: min(elapsed, durationSeconds))
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func saveSession(completed: Bool, timeSpentSeconds: Int) {
        guard !isTest else { return }
        let session = IntensitySession(
            committedAt: timerStartDate,
            committedUntil: committedUntil,
            durationSeconds: durationSeconds,
            completed: completed,
            timeSpentSeconds: timeSpentSeconds,
            distractionCount: distractionCount
        )
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
                content.title = "Focus session complete"
                content.body = "You held undistracted focus until \(focusUntilString)."
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: TimeInterval(durationSeconds),
                    repeats: false
                )
                try await center.add(
                    UNNotificationRequest(identifier: "timerz.intensity.expiry", content: content, trigger: trigger)
                )
            } catch {}
        }
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["timerz.intensity.expiry"])
    }

    private func consumeAnnouncements(remaining: Int, speak allowSpeak: Bool) {
        while let next = pendingAnnouncements.first, remaining <= next {
            if allowSpeak, remaining == next {
                announce(next)
            }
            pendingAnnouncements.removeFirst()
        }
    }

    private func announce(_ threshold: Int) {
        guard sessionVerbalCountdownEnabled, !isTest else { return }
        let text: String
        switch threshold {
        case 10: text = "Ten"
        case 5: text = "Five"
        case 60...: text = "\(threshold / 60) minute\(threshold == 60 ? "" : "s") remaining"
        default: text = "\(threshold) seconds remaining"
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        speechSynthesizer.speak(AVSpeechUtterance(string: text))
    }

    private func stopAnnouncements() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}

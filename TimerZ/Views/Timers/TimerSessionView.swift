import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import AudioToolbox
import AVFoundation

struct TimerSessionView: View {
    let durationSeconds: Int
    let isTest: Bool
    let isBreak: Bool
    let onDismiss: @MainActor () -> Void
    let onDismissAndAmend: (@MainActor () -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Keys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(Keys.soundEnabled) private var soundEnabled = true
    @AppStorage(Keys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(Keys.expirySound) private var expirySoundID: Int = 1107
    @AppStorage(Keys.verbalCountdownEnabled) private var verbalCountdownEnabled = true
    @AppStorage(Keys.timerPresets) private var presetsString: String = "5,10,15,25"
    @AppStorage(Keys.bankedSeconds) private var bankedSeconds: Int = 0

    @State private var secondsRemaining: Int
    @State private var secondsElapsed = 0
    @State private var isCountUp: Bool
    @State private var sessionState: SessionState = .running
    @State private var showCancelAlert = false
    @State private var timerStartDate = Date()
    @State private var pendingAnnouncements: [Int] = []
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var sessionVerbalCountdownEnabled = true
    @State private var lastAccruedSeconds = 0

    enum SessionState { case running, won, lost }

    init(
        durationSeconds: Int,
        isTest: Bool = false,
        isBreak: Bool = false,
        isCountUp: Bool = false,
        onDismiss: @escaping @MainActor () -> Void,
        onDismissAndAmend: (@MainActor () -> Void)? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.isTest = isTest
        self.isBreak = isBreak
        self.onDismiss = onDismiss
        self.onDismissAndAmend = onDismissAndAmend
        _secondsRemaining = State(initialValue: durationSeconds)
        _isCountUp = State(initialValue: isCountUp)
    }

    private var displaySeconds: Int { isCountUp ? secondsElapsed : secondsRemaining }

    private var presets: [Int] {
        presetsString
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private var timeString: String {
        let m = displaySeconds / 60
        let s = displaySeconds % 60
        return String(format: "%02d:%02d", m, s)
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
                    Text(durationSeconds < 60 ? "\(durationSeconds) sec session" : "\(durationSeconds / 60) min session")
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
                .padding(.bottom, 8)

                // Countdown
                Text(timeString)
                    .font(.system(size: 88, weight: .bold, design: .monospaced))
                    .foregroundStyle(sessionState == .lost ? .red : .primary)
                    .contentTransition(.numericText(countsDown: !isCountUp))
                    .animation(.default, value: displaySeconds)
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

            if sessionState == .won && !isBreak && lastAccruedSeconds > 0 {
                ConfettiView()
                    .ignoresSafeArea()
                    .transition(.identity)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            timerStartDate = Date()
            sessionVerbalCountdownEnabled = verbalCountdownEnabled
            pendingAnnouncements = announcementThresholds
            if notificationsEnabled && !isTest && !isCountUp {
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
            if isCountUp {
                withAnimation { secondsElapsed = min(elapsed, durationSeconds) }
                consumeAnnouncements(remaining: remaining, speak: true)
                if elapsed >= durationSeconds { win() }
            } else {
                withAnimation { secondsRemaining = remaining }
                consumeAnnouncements(remaining: remaining, speak: true)
                if remaining == 0 { lose() }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, sessionState == .running else { return }
            let elapsed = Int(Date().timeIntervalSince(timerStartDate))
            let remaining = max(0, durationSeconds - elapsed)
            if isCountUp {
                secondsElapsed = min(elapsed, durationSeconds)
                consumeAnnouncements(remaining: remaining, speak: false)
                if elapsed >= durationSeconds { win() }
            } else {
                secondsRemaining = remaining
                consumeAnnouncements(remaining: remaining, speak: false)
                if remaining == 0 { lose() }
            }
        }
        .alert("Cancel session?", isPresented: $showCancelAlert) {
            Button("Keep Going", role: .cancel) {}
            Button("Cancel Session", role: .destructive) {
                cancelNotification()
                stopAnnouncements()
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
            Text(isBreak ? "Break's over!" : "You did it!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            if !isBreak && lastAccruedSeconds > 0 {
                accrualToast
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var accrualToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
            accrualMessage
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.teal, in: Capsule())
        .shadow(color: .teal.opacity(0.4), radius: 8, x: 0, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var accrualMessage: Text {
        let (quantity, unit) = accruedQuantityAndUnit
        return Text("You accrued ")
            + Text(quantity).foregroundStyle(.yellow)
            + Text(" \(unit)!")
    }

    private var accruedQuantityAndUnit: (quantity: String, unit: String) {
        if lastAccruedSeconds >= 60 {
            let minutes = lastAccruedSeconds / 60
            let remainder = lastAccruedSeconds % 60
            let quantity = remainder > 0 ? "\(minutes)+" : "\(minutes)"
            let unit = (minutes == 1 && remainder == 0) ? "min" : "mins"
            return (quantity, unit)
        } else {
            let unit = lastAccruedSeconds == 1 ? "sec" : "secs"
            return ("\(lastAccruedSeconds)", unit)
        }
    }

    private var lostView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.red)
            Text(isBreak ? "Break's over!" : "Time's up!")
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
        let timeSpent = isCountUp ? secondsElapsed : (durationSeconds - secondsRemaining)
        withAnimation(.spring(duration: 0.4)) { sessionState = .won }
        cancelNotification()
        stopAnnouncements()
        if isBreak {
            spendBank(seconds: timeSpent)
        } else {
            saveSession(isWin: true, timeSpentSeconds: timeSpent)
            lastAccruedSeconds = accrueBank(elapsed: timeSpent)
        }
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        let dismissDelay = (!isBreak && lastAccruedSeconds > 0) ? 2.0 : 1.5
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(dismissDelay))
            onDismiss()
        }
    }

    private func lose() {
        guard sessionState == .running else { return }
        withAnimation(.spring(duration: 0.4)) { sessionState = .lost }
        cancelNotification()
        stopAnnouncements()
        if isBreak {
            spendBank(seconds: durationSeconds)
        } else {
            saveSession(isWin: false)
        }
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        if soundEnabled {
            let soundID = SystemSoundID(expirySoundID)
            Task {
                for _ in 0..<3 {
                    AudioServicesPlayAlertSound(soundID)
                    try? await Task.sleep(for: .milliseconds(800))
                }
            }
        }
    }

    private func saveSession(isWin: Bool, timeSpentSeconds: Int = 0) {
        guard !isTest else { return }
        let session = Session(durationSeconds: durationSeconds, isWin: isWin, timeSpentSeconds: timeSpentSeconds)
        modelContext.insert(session)
        try? modelContext.save()
    }

    @discardableResult
    private func accrueBank(elapsed: Int) -> Int {
        guard !isTest else { return 0 }
        let rungs = presets.map { $0 * 60 }.sorted()
        guard let rung = rungs.first(where: { $0 >= elapsed }) else { return 0 }
        let earned = rung - elapsed
        guard earned > 0 else { return 0 }
        bankedSeconds += earned
        return earned
    }

    private func spendBank(seconds: Int) {
        bankedSeconds = max(0, bankedSeconds - seconds)
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

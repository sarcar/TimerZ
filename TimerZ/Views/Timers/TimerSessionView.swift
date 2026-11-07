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
    let taskName: String?
    let isChainContinuation: Bool
    let onDismiss: @MainActor () -> Void
    let onDismissAndAmend: (@MainActor () -> Void)?
    let onDismissAndStartNext: (@MainActor (Int) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @AppStorage(Keys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(Keys.soundEnabled) private var soundEnabled = true
    @AppStorage(Keys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(Keys.expirySound) private var expirySoundID: Int = 1107
    @AppStorage(Keys.timerPresets) private var presetsString: String = "5,10,15,25"
    @AppStorage(Keys.bankedSeconds) private var bankedSeconds: Int = 0
    @AppStorage(Keys.showChainPresetPicker) private var showChainPresetPicker = false
    @AppStorage(Keys.bestChainCount) private var bestChainCount = 0
    @AppStorage(Keys.bestChainDurationSeconds) private var bestChainDurationSeconds = 0

    @State private var secondsRemaining: Int
    @State private var secondsElapsed = 0
    @State private var isCountUp: Bool
    @State private var sessionState: SessionState = .running
    @State private var showCancelAlert = false
    @State private var timerStartDate = Date()
    @State private var pendingAnnouncements: [Int] = []
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var showAudioCueLevelPicker = false
    @State private var lastAccruedSeconds = 0
    @State private var backgroundAudioKeepAlive = BackgroundAudioKeepAlive()
    @State private var showChainSheet = false
    @State private var chainCelebrationCount: Int?
    private let checkmarkLongPressDuration: TimeInterval = 0.5

    enum SessionState { case running, won, lost }

    init(
        durationSeconds: Int,
        isTest: Bool = false,
        isBreak: Bool = false,
        isCountUp: Bool = false,
        taskName: String? = nil,
        isChainContinuation: Bool = false,
        onDismiss: @escaping @MainActor () -> Void,
        onDismissAndAmend: (@MainActor () -> Void)? = nil,
        onDismissAndStartNext: (@MainActor (Int) -> Void)? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.isTest = isTest
        self.isBreak = isBreak
        self.taskName = taskName
        self.isChainContinuation = isChainContinuation
        self.onDismiss = onDismiss
        self.onDismissAndAmend = onDismissAndAmend
        self.onDismissAndStartNext = onDismissAndStartNext
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

                if let taskName {
                    Text(taskName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)
                }

                // Duration label
                HStack(spacing: 6) {
                    if sessionState == .running {
                        speakerControl
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

            if sessionState == .won && !isBreak && (lastAccruedSeconds > 0 || chainCelebrationCount != nil) {
                ConfettiView()
                    .ignoresSafeArea()
                    .transition(.identity)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            timerStartDate = Date()
            pendingAnnouncements = announcementThresholds
            if !isTest && !isChainContinuation {
                appState.currentChainCount = 1
                appState.currentChainElapsedSeconds = 0
            }
            if !isTest && (notificationsEnabled || soundEnabled) {
                scheduleNotification()
            }
            if !isTest && appState.audioCueLevel != .muted {
                backgroundAudioKeepAlive.start()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            backgroundAudioKeepAlive.stop()
        }
        .onChange(of: appState.audioCueLevel) { _, newLevel in
            guard !isTest else { return }
            if newLevel != .muted {
                backgroundAudioKeepAlive.start()
            } else {
                backgroundAudioKeepAlive.stop()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard sessionState == .running else { return }
            let elapsed = Int(Date().timeIntervalSince(timerStartDate))
            let remaining = max(0, durationSeconds - elapsed)
            if isCountUp {
                withAnimation { secondsElapsed = min(elapsed, durationSeconds) }
                if !consumeAnnouncements(remaining: remaining, speak: true) {
                    playAudioCue(remaining: remaining)
                }
                if elapsed >= durationSeconds { win(isAutoComplete: true) }
            } else {
                withAnimation { secondsRemaining = remaining }
                if !consumeAnnouncements(remaining: remaining, speak: true) {
                    playAudioCue(remaining: remaining)
                }
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
                if elapsed >= durationSeconds { win(isAutoComplete: true) }
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
                backgroundAudioKeepAlive.stop()
                if !isTest && !isBreak {
                    finalizeChain(addingElapsed: nil)
                }
                onDismiss()
            }
        } message: {
            Text("This session won't be saved.")
        }
        .confirmationDialog("Start Next", isPresented: $showChainSheet, titleVisibility: .visible) {
            ForEach(presets, id: \.self) { minutes in
                Button("\(minutes) min") {
                    if let onDismissAndStartNext {
                        onDismissAndStartNext(minutes * 60)
                    } else {
                        if !isTest { finalizeChain(addingElapsed: nil) }
                        onDismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                if !isTest {
                    finalizeChain(addingElapsed: nil)
                }
                onDismiss()
            }
        }
    }

    // MARK: - Sub-views

    private var audioCueLevelBinding: Binding<AudioCueLevel> {
        Binding(
            get: { appState.audioCueLevel },
            set: { newLevel in
                appState.audioCueLevel = newLevel
                if newLevel != .muted { appState.lastNonMutedAudioCueLevel = newLevel }
            }
        )
    }

    private var speakMinuteMarksBinding: Binding<Bool> {
        Binding(
            get: { appState.speakMinuteMarks },
            set: { appState.speakMinuteMarks = $0 }
        )
    }

    private var speakerControl: some View {
        let tap = TapGesture().onEnded {
            showAudioCueLevelPicker = true
        }
        let longPress = LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            if appState.audioCueLevel == .muted {
                appState.audioCueLevel = appState.lastNonMutedAudioCueLevel
            } else {
                appState.lastNonMutedAudioCueLevel = appState.audioCueLevel
                appState.audioCueLevel = .muted
            }
        }

        return Image(systemName: appState.audioCueLevel == .muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            .font(.subheadline)
            .foregroundStyle(.blue)
            .contentShape(Rectangle())
            .gesture(longPress.exclusively(before: tap))
            .accessibilityLabel(
                appState.audioCueLevel == .muted
                    ? "Muted. Hold to unmute, tap for cue level options."
                    : "\(appState.audioCueLevel.label). Hold to mute, tap for cue level options."
            )
            .sheet(isPresented: $showAudioCueLevelPicker) {
                AudioCueSheet(level: audioCueLevelBinding, speakMinuteMarks: speakMinuteMarksBinding)
            }
    }

    @ViewBuilder
    private var checkmarkButton: some View {
        let label = Image(systemName: "checkmark")
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 130, height: 130)
            .background(Color.green)
            .clipShape(Circle())
            .shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)

        if isBreak || isTest {
            Button {
                win()
            } label: {
                label
            }
            .accessibilityLabel("Complete")
        } else {
            let tap = TapGesture().onEnded {
                win()
            }
            let longPress = LongPressGesture(minimumDuration: checkmarkLongPressDuration).onEnded { _ in
                winViaLongPress()
            }

            label
                .contentShape(Circle())
                .gesture(longPress.exclusively(before: tap))
                .accessibilityLabel("Complete. Hold to complete and start another timer.")
        }
    }

    private var wonView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.green)
            Text(isBreak ? "Break's over!" : "You did it!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            if !isBreak, let chainCelebrationCount {
                chainToast(count: chainCelebrationCount)
            } else if !isBreak && lastAccruedSeconds > 0 {
                accrualToast
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    private func chainToast(count: Int) -> some View {
        HStack(spacing: 6) {
            Text("🔥")
            Text("\(count) in a row!").fontWeight(.bold)
            Text("·")
            Text(chainDurationText)
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing),
            in: Capsule()
        )
        .shadow(color: Color.orange.opacity(0.5), radius: 8, x: 0, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var chainDurationText: String {
        let minutes = max(1, appState.currentChainElapsedSeconds / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder > 0 ? "\(hours)h \(remainder)m focused" : "\(hours)h focused"
        }
        return "\(minutes) min focused"
    }

    private var accrualToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
            accrualMessage
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundStyle(.yellow)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.05, green: 0.08, blue: 0.35), in: Capsule())
        .shadow(color: Color(red: 0.05, green: 0.08, blue: 0.35).opacity(0.5), radius: 8, x: 0, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var accrualMessage: Text {
        let (quantity, unit) = accruedQuantityAndUnit
        return Text("You accrued ")
            + Text(quantity).foregroundStyle(.pink).fontWeight(.bold)
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

    private func winViaLongPress() {
        guard sessionState == .running else { return }
        // LongPressGesture's onEnded fires the instant the hold duration is
        // satisfied, not on finger-lift, so "now minus the hold duration" is
        // an accurate stand-in for when the press actually began — without
        // needing a separate onChanged-tracked timestamp.
        let anchor = Date().addingTimeInterval(-checkmarkLongPressDuration)
        let elapsed = min(durationSeconds, max(0, Int(anchor.timeIntervalSince(timerStartDate))))

        if !isTest {
            appState.currentChainElapsedSeconds += elapsed
            appState.currentChainCount += 1
            chainCelebrationCount = appState.currentChainCount
        }

        win(elapsedOverride: elapsed, suppressAutoDismiss: true, suppressAccrual: true)

        if showChainPresetPicker {
            showChainSheet = true
        } else {
            let nextDuration = durationSeconds
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.4))
                if let onDismissAndStartNext {
                    onDismissAndStartNext(nextDuration)
                } else {
                    onDismiss()
                }
            }
        }
    }

    private func win(isAutoComplete: Bool = false, elapsedOverride: Int? = nil, suppressAutoDismiss: Bool = false, suppressAccrual: Bool = false) {
        guard sessionState == .running else { return }
        let timeSpent = elapsedOverride ?? (isCountUp ? secondsElapsed : (durationSeconds - secondsRemaining))
        withAnimation(.spring(duration: 0.4)) { sessionState = .won }
        cancelNotification()
        stopAnnouncements()
        if isBreak {
            spendBank(seconds: timeSpent)
        } else if suppressAccrual {
            lastAccruedSeconds = 0
            saveSession(isWin: true, timeSpentSeconds: timeSpent, accruedSeconds: 0)
        } else {
            lastAccruedSeconds = accrueBank(elapsed: timeSpent)
            saveSession(isWin: true, timeSpentSeconds: timeSpent, accruedSeconds: lastAccruedSeconds)
            if !isTest {
                finalizeChain(addingElapsed: timeSpent)
            }
        }
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if !isBreak && lastAccruedSeconds > 0 {
            playAccrualBuzz()
        }
        if isAutoComplete && soundEnabled {
            let soundID = SystemSoundID(expirySoundID)
            Task {
                for _ in 0..<3 {
                    AudioServicesPlayAlertSound(soundID)
                    try? await Task.sleep(for: .milliseconds(800))
                }
            }
        }
        guard !suppressAutoDismiss else { return }
        let dismissDelay = (!isBreak && lastAccruedSeconds > 0) ? 3.0 : 1.5
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
            if !isTest {
                finalizeChain(addingElapsed: durationSeconds)
            }
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

    private func finalizeChain(addingElapsed elapsed: Int?) {
        let finalCount = appState.currentChainCount
        let finalElapsed = appState.currentChainElapsedSeconds + (elapsed ?? 0)
        if finalCount >= 2 {
            bestChainCount = max(bestChainCount, finalCount)
            bestChainDurationSeconds = max(bestChainDurationSeconds, finalElapsed)
        }
        appState.currentChainCount = 1
        appState.currentChainElapsedSeconds = 0
    }

    private func saveSession(isWin: Bool, timeSpentSeconds: Int = 0, accruedSeconds: Int = 0) {
        guard !isTest else { return }
        let session = Session(
            durationSeconds: durationSeconds,
            isWin: isWin,
            timeSpentSeconds: timeSpentSeconds,
            accruedSeconds: accruedSeconds,
            taskName: taskName
        )
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

    private func playAccrualBuzz() {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        Task {
            for _ in 0..<4 {
                generator.impactOccurred()
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }

    private func scheduleNotification() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard granted else { return }

                let content = UNMutableNotificationContent()
                if isCountUp {
                    content.title = "Session complete!"
                    content.body = "Your \(durationSeconds / 60)-min count-up session is done."
                } else {
                    content.title = "Time's up!"
                    content.body = "Your \(durationSeconds / 60)-min session has ended."
                }
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

    @discardableResult
    private func consumeAnnouncements(remaining: Int, speak allowSpeak: Bool) -> Bool {
        var spoke = false
        while let next = pendingAnnouncements.first, remaining <= next {
            if allowSpeak {
                announce(next)
                spoke = true
            }
            pendingAnnouncements.removeFirst()
        }
        return spoke
    }

    private func announce(_ threshold: Int) {
        guard appState.audioCueLevel != .muted, !isTest else { return }
        let text: String
        switch threshold {
        case 10: text = "Ten"
        case 5: text = "Five"
        case 60...: text = AudioCueLevel.minuteRemainingText(threshold / 60)
        default: text = "\(threshold) seconds remaining"
        }
        speechSynthesizer.speak(AVSpeechUtterance(string: text))
    }

    private func playAudioCue(remaining: Int) {
        appState.audioCueLevel.playCue(remaining: remaining, speakMinuteMarks: appState.speakMinuteMarks) { minutes in
            speechSynthesizer.speak(AVSpeechUtterance(string: AudioCueLevel.minuteRemainingText(minutes)))
        }
    }

    private func stopAnnouncements() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}

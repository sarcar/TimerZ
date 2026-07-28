import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import AVFoundation
import AudioToolbox

private struct SubTimerRun {
    enum State { case running, won, lost }

    let durationSeconds: Int
    let isTest: Bool
    var secondsRemaining: Int
    var secondsElapsed: Int = 0
    var isCountUp: Bool = false
    var state: State = .running
    var startDate: Date = Date()
    var pendingAnnouncements: [Int] = []
}

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
    @AppStorage(Keys.soundEnabled) private var soundEnabled = true
    @AppStorage(Keys.expirySound) private var expirySoundID: Int = 1107
    @AppStorage(Keys.timerPresets) private var presetsString: String = "5,10,15,25"

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
    @State private var gongPlayer: AVAudioPlayer?
    @State private var showSubTimerPicker = false
    @State private var subTimer: SubTimerRun?

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

    private var isSubTimerRunning: Bool { subTimer?.state == .running }
    private var isSubTimerUIActive: Bool { subTimer != nil || showSubTimerPicker }

    private var eligiblePresets: [Int] {
        presetsString
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 * 60 <= secondsRemaining }
    }

    private func subTimeString(_ sub: SubTimerRun) -> String {
        let displaySeconds = sub.isCountUp ? sub.secondsElapsed : sub.secondsRemaining
        let m = displaySeconds / 60
        let s = displaySeconds % 60
        return String(format: "%02d:%02d", m, s)
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

                // Countdown: full ring normally, slim bar when a sub-timer takes over the screen
                Group {
                    if isSubTimerUIActive {
                        VStack(spacing: 6) {
                            ProgressView(value: progress)
                                .tint(ringColor)
                            Text(timeString)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 40)
                    } else {
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
                    }
                }
                .padding(.bottom, isSubTimerUIActive ? 24 : 48)
                .animation(.spring(duration: 0.4), value: isSubTimerUIActive)

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
            if sessionState == .running { tick(speak: true) }
            if isSubTimerRunning { tickSubTimer(speak: true) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            if sessionState == .running { tick(speak: false) }
            if isSubTimerRunning { tickSubTimer(speak: false) }
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
        Group {
            if let sub = subTimer {
                switch sub.state {
                case .running:
                    subTimerRunningView(sub)
                case .won:
                    subTimerWonView
                case .lost:
                    subTimerLostView
                }
            } else if showSubTimerPicker {
                subTimerPickerRow
            } else {
                startSubTimerButton
            }
        }
        .frame(minHeight: 130)
        .animation(.spring(duration: 0.4), value: subTimer?.state)
        .animation(.default, value: showSubTimerPicker)
    }

    private var startSubTimerButton: some View {
        VStack(spacing: 8) {
            Text("Stay the course.")
                .font(.subheadline)
                .foregroundStyle(.secondary.opacity(0.6))
            Button {
                showSubTimerPicker = true
            } label: {
                Label("Start Sub-Timer", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
            }
        }
    }

    private var subTimerPickerRow: some View {
        VStack(spacing: 12) {
            if eligiblePresets.isEmpty {
                Text("Not enough time left in this session for a sub-timer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(eligiblePresets, id: \.self) { minutes in
                        Button {
                            startSubTimer(durationSeconds: minutes * 60, isTest: false)
                        } label: {
                            Text("\(minutes) min")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.indigo.opacity(0.15))
                                .foregroundStyle(.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            if appState.testModeEnabled {
                Button {
                    startSubTimer(durationSeconds: 3, isTest: true)
                } label: {
                    Text("Test (3 sec)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Button("Cancel") {
                showSubTimerPicker = false
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func subTimerRunningView(_ sub: SubTimerRun) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(sub.durationSeconds < 60 ? "\(sub.durationSeconds) sec sub-timer" : "\(sub.durationSeconds / 60) min sub-timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    subTimer?.isCountUp.toggle()
                } label: {
                    Image(systemName: sub.isCountUp ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(subTimeString(sub))
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .contentTransition(.numericText(countsDown: !sub.isCountUp))
                .animation(.default, value: sub.secondsRemaining)
                .animation(.default, value: sub.secondsElapsed)
            Button {
                winSubTimer()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.green)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Complete sub-timer")
        }
    }

    private var subTimerWonView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("Sub-timer done!")
                .font(.headline)
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var subTimerLostView: some View {
        VStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            Text("Sub-timer time's up.")
                .font(.headline)
            Button("Done") {
                subTimer = nil
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .transition(.scale.combined(with: .opacity))
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
        consumeAnnouncements(remaining: remaining, speak: speak && !isSubTimerRunning)
        if remaining == 0 { complete() }
    }

    private func tickSubTimer(speak: Bool) {
        guard var sub = subTimer, sub.state == .running else { return }
        let elapsed = Int(Date().timeIntervalSince(sub.startDate))
        let remaining = max(0, sub.durationSeconds - elapsed)

        if sub.isCountUp {
            sub.secondsElapsed = min(elapsed, sub.durationSeconds)
        } else {
            sub.secondsRemaining = remaining
        }
        consumeSubAnnouncements(&sub, remaining: remaining, speak: speak)

        withAnimation { subTimer = sub }

        if sub.isCountUp {
            if elapsed >= sub.durationSeconds { winSubTimer() }
        } else if remaining == 0 {
            loseSubTimer()
        }
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
        if isSubTimerRunning {
            forceResolveSubTimer(asWin: true)
        }
        withAnimation(.spring(duration: 0.4)) { sessionState = .completed }
        cancelNotification()
        stopAnnouncements()
        saveSession(completed: true, timeSpentSeconds: durationSeconds)
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        playCompletionAnnouncementThenDismiss()
    }

    private func playCompletionAnnouncementThenDismiss() {
        let minutes = durationSeconds / 60
        let sentence = "You have completed a \(minutes) minute focus session."

        Task { @MainActor in
            var delay: Double = 1.2

            if soundEnabled, let url = Bundle.main.url(forResource: "Gong", withExtension: "mp3") {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.duckOthers])
                    try AVAudioSession.sharedInstance().setActive(true)
                    let player = try AVAudioPlayer(contentsOf: url)
                    gongPlayer = player
                    player.play()
                    delay = player.duration + 0.3
                } catch {}
            }
            try? await Task.sleep(for: .seconds(delay))

            if sessionVerbalCountdownEnabled {
                speechSynthesizer.speak(AVSpeechUtterance(string: sentence))
                let wordCount = sentence.split(separator: " ").count
                try? await Task.sleep(for: .seconds(Double(wordCount) * 0.35 + 0.6))
            }

            onDismiss()
        }
    }

    private func quit(discard: Bool) {
        guard sessionState == .running else { return }
        cancelNotification()
        stopAnnouncements()
        if discard {
            subTimer = nil
            onDismiss()
            return
        }
        if isSubTimerRunning {
            forceResolveSubTimer(asWin: false)
        }
        let elapsed = Int(Date().timeIntervalSince(timerStartDate))
        withAnimation(.spring(duration: 0.4)) { sessionState = .broken }
        saveSession(completed: false, timeSpentSeconds: min(elapsed, durationSeconds))
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func startSubTimer(durationSeconds: Int, isTest: Bool) {
        showSubTimerPicker = false
        var sub = SubTimerRun(durationSeconds: durationSeconds, isTest: isTest, secondsRemaining: durationSeconds)
        sub.pendingAnnouncements = subAnnouncementThresholds(for: durationSeconds)
        subTimer = sub
    }

    private func winSubTimer() {
        guard var sub = subTimer, sub.state == .running else { return }
        let timeSpent = sub.isCountUp ? sub.secondsElapsed : (sub.durationSeconds - sub.secondsRemaining)
        sub.state = .won
        withAnimation(.spring(duration: 0.4)) { subTimer = sub }
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        saveSubTimerSession(sub, isWin: true, timeSpent: timeSpent)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if subTimer?.state == .won { subTimer = nil }
        }
    }

    private func loseSubTimer() {
        guard var sub = subTimer, sub.state == .running else { return }
        sub.state = .lost
        withAnimation(.spring(duration: 0.4)) { subTimer = sub }
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        saveSubTimerSession(sub, isWin: false, timeSpent: 0)
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

    private func forceResolveSubTimer(asWin: Bool) {
        guard let sub = subTimer, sub.state == .running else { return }
        let elapsed = Int(Date().timeIntervalSince(sub.startDate))
        let timeSpent = min(elapsed, sub.durationSeconds)
        saveSubTimerSession(sub, isWin: asWin, timeSpent: timeSpent)
        subTimer = nil
    }

    private func saveSubTimerSession(_ sub: SubTimerRun, isWin: Bool, timeSpent: Int) {
        guard !sub.isTest else { return }
        let session = Session(durationSeconds: sub.durationSeconds, isWin: isWin, timeSpentSeconds: isWin ? timeSpent : 0)
        modelContext.insert(session)
        try? modelContext.save()
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

    private func subAnnouncementThresholds(for durationSeconds: Int) -> [Int] {
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

    private func consumeSubAnnouncements(_ sub: inout SubTimerRun, remaining: Int, speak allowSpeak: Bool) {
        while let next = sub.pendingAnnouncements.first, remaining <= next {
            if allowSpeak, remaining == next, !sub.isTest {
                announceSub(next)
            }
            sub.pendingAnnouncements.removeFirst()
        }
    }

    private func announceSub(_ threshold: Int) {
        guard sessionVerbalCountdownEnabled else { return }
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
}

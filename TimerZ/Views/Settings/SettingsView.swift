import SwiftUI
import SwiftData
import UIKit
import AudioToolbox

struct SettingsView: View {
    @AppStorage(Keys.timerPresets) private var presetsString: String = "5,10,15,25"
    @AppStorage(Keys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(Keys.soundEnabled) private var soundEnabled = true
    @AppStorage(Keys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(Keys.expirySound) private var expirySoundID: Int = 1107
    @AppStorage(Keys.verbalCountdownEnabled) private var verbalCountdownEnabled = true
    @AppStorage(Keys.dialFeedbackEnabled) private var dialFeedbackEnabled = true
    @AppStorage(Keys.doubleBeepSoundID) private var doubleBeepSoundID: Int = 1210
    @AppStorage(Keys.singleBeepSoundID) private var singleBeepSoundID: Int = 1104
    @AppStorage(Keys.tickSoundID) private var tickSoundID: Int = 1157
    @Environment(AppState.self) private var appState

    @Environment(\.modelContext) private var modelContext
    @Query(SettingsView.lastSessionDescriptor) private var sessions: [Session]
    @Query(SettingsView.lastIntensitySessionDescriptor) private var intensitySessions: [IntensitySession]

    @State private var showAddPreset = false
    @State private var newMinutes = ""
    @State private var showClearConfirm = false
    @State private var showNothingToClear = false
    @State private var showAmendSheet = false
    @State private var showAmendIntensitySheet = false
    @State private var pendingClearRange: ClearDataRange?
    @State private var pendingClearSessions: [Session] = []
    @State private var pendingClearIntensitySessions: [IntensitySession] = []
    @FocusState private var focusedSoundIDField: SoundIDField?

    private enum SoundIDField: Hashable {
        case doubleBeep, singleBeep, tick
    }

    private enum ClearDataRange: String, CaseIterable, Identifiable {
        case last30Minutes = "Last 30 mins"
        case lastHour = "Last 1 hour"
        case last24Hours = "Last 24 hours"
        case last7Days = "Last 7 days"
        case allTime = "Since Big Bang"

        var id: String { rawValue }

        var cutoffDate: Date? {
            let now = Date()
            switch self {
            case .last30Minutes: return Calendar.current.date(byAdding: .minute, value: -30, to: now)
            case .lastHour: return Calendar.current.date(byAdding: .hour, value: -1, to: now)
            case .last24Hours: return Calendar.current.date(byAdding: .hour, value: -24, to: now)
            case .last7Days: return Calendar.current.date(byAdding: .day, value: -7, to: now)
            case .allTime: return nil
            }
        }

        var rangeDescription: String {
            switch self {
            case .last30Minutes: return "the last 30 minutes"
            case .lastHour: return "the last hour"
            case .last24Hours: return "the last 24 hours"
            case .last7Days: return "the last 7 days"
            case .allTime: return "all time"
            }
        }
    }

    private var lastSession: Session? { sessions.first }
    private var lastIntensitySession: IntensitySession? { intensitySessions.first }

    private static var lastSessionDescriptor: FetchDescriptor<Session> {
        var descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    private static var lastIntensitySessionDescriptor: FetchDescriptor<IntensitySession> {
        var descriptor = FetchDescriptor<IntensitySession>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    private var presets: [Int] {
        presetsString
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func setPresets(_ updated: [Int]) {
        presetsString = updated.map { String($0) }.joined(separator: ",")
    }

    private func requestClear(_ range: ClearDataRange) {
        let cutoff = range.cutoffDate
        let sessionDescriptor: FetchDescriptor<Session> = cutoff.map { date in
            FetchDescriptor<Session>(predicate: #Predicate { $0.completedAt >= date })
        } ?? FetchDescriptor<Session>()
        let intensityDescriptor: FetchDescriptor<IntensitySession> = cutoff.map { date in
            FetchDescriptor<IntensitySession>(predicate: #Predicate { $0.completedAt >= date })
        } ?? FetchDescriptor<IntensitySession>()

        pendingClearRange = range
        pendingClearSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []
        pendingClearIntensitySessions = (try? modelContext.fetch(intensityDescriptor)) ?? []

        if pendingClearSessions.isEmpty && pendingClearIntensitySessions.isEmpty {
            showNothingToClear = true
        } else {
            showClearConfirm = true
        }
    }

    private func performClear() {
        for session in pendingClearSessions { modelContext.delete(session) }
        for session in pendingClearIntensitySessions { modelContext.delete(session) }
        try? modelContext.save()
        pendingClearSessions = []
        pendingClearIntensitySessions = []
    }

    private var clearConfirmMessage: String {
        var parts: [String] = []
        if !pendingClearSessions.isEmpty {
            parts.append("\(pendingClearSessions.count) timer session\(pendingClearSessions.count == 1 ? "" : "s")")
        }
        if !pendingClearIntensitySessions.isEmpty {
            parts.append("\(pendingClearIntensitySessions.count) Intensity session\(pendingClearIntensitySessions.count == 1 ? "" : "s")")
        }
        let combined = parts.joined(separator: " and ")
        let range = pendingClearRange?.rangeDescription ?? "the selected range"
        return "This will permanently delete \(combined) from \(range). This cannot be undone."
    }

    private func audioCueSoundRow(label: String, id: Binding<Int>, field: SoundIDField) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("ID", value: id, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .focused($focusedSoundIDField, equals: field)
            Button {
                AudioServicesPlaySystemSound(SystemSoundID(id.wrappedValue))
            } label: {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.indigo)
            }
            .buttonStyle(.plain)
        }
    }

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItem {
            EditButton()
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                focusedSoundIDField = nil
            }
        }
    }

    private var presetsSection: some View {
        Section {
            ForEach(presets, id: \.self) { minutes in
                Text("\(minutes) min")
            }
            .onDelete { offsets in
                guard presets.count > 1 else { return }
                var updated = presets
                updated.remove(atOffsets: offsets)
                setPresets(updated)
            }
            .onMove { source, destination in
                var updated = presets
                updated.move(fromOffsets: source, toOffset: destination)
                setPresets(updated)
            }

            if presets.count < 8 {
                Button {
                    showAddPreset = true
                } label: {
                    Label("Add Preset", systemImage: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("Timer Presets")
        } footer: {
            Text("Up to 8 presets. Use Edit to reorder or delete.")
        }
    }

    private var notificationsSection: some View {
        Section("Notifications & Feedback") {
            Toggle("Background Notifications", isOn: $notificationsEnabled)
            Toggle("Haptic Feedback", isOn: $hapticsEnabled)
            Toggle("Sound on Expiry", isOn: $soundEnabled)
            if soundEnabled {
                Picker("Expiry Sound", selection: $expirySoundID) {
                    Text("Tri-tone").tag(1003)
                    Text("Sci-fi").tag(1107)
                    Text("Glass").tag(1322)
                    Text("Alarm").tag(1304)
                    Text("Vibrate").tag(4095)
                    Text("New Mail").tag(1000)
                    Text("Whoosh").tag(1001)
                    Text("Lock").tag(1006)
                    Text("Bells").tag(1013)
                }
                .onChange(of: expirySoundID) { _, newValue in
                    AudioServicesPlayAlertSound(SystemSoundID(newValue))
                }
            }
            Toggle("Verbal Countdown", isOn: $verbalCountdownEnabled)
        }
    }

    private var audioCueSoundsSection: some View {
        Section {
            audioCueSoundRow(label: "Double Beep (Level 2)", id: $doubleBeepSoundID, field: .doubleBeep)
            audioCueSoundRow(label: "Single Beep (Level 3)", id: $singleBeepSoundID, field: .singleBeep)
            audioCueSoundRow(label: "Tick (Level 4)", id: $tickSoundID, field: .tick)
        } header: {
            Text("Audio Cue Sounds")
        } footer: {
            Text("iOS system sound IDs used by the Level 2–4 audio cues (long-press the speaker icon on a timer to choose a level). Tap play to preview.")
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button {
                showAmendSheet = true
            } label: {
                Label("Amend Last Session", systemImage: "pencil.circle")
            }
            .disabled(lastSession == nil)

            Button {
                showAmendIntensitySheet = true
            } label: {
                Label("Amend Last Intensity Session", systemImage: "pencil.circle")
            }
            .disabled(lastIntensitySession == nil)

            Menu {
                ForEach(ClearDataRange.allCases) { range in
                    Button(range.rawValue, role: .destructive) {
                        requestClear(range)
                    }
                }
            } label: {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            Form {
                presetsSection
                notificationsSection
                audioCueSoundsSection

                Section {
                    Toggle("Dial Feedback", isOn: $dialFeedbackEnabled)
                } header: {
                    Text("Intensity Dial")
                } footer: {
                    Text("Haptic ticks and a soft tick sound while adjusting the Intensity duration dial. Independent of the Haptic Feedback and Sound settings above.")
                }

                Section {
                    Toggle("Test Mode", isOn: $appState.testModeEnabled)
                } header: {
                    Text("Test")
                } footer: {
                    Text("Adds a 3-second timer button to the home screen for quick testing.")
                }

                dataSection
            }
            .navigationTitle("Settings")
            .scrollDismissesKeyboard(.interactively)
            .toolbar { keyboardToolbar }
        }
        .sheet(isPresented: $showAmendSheet) {
            if let session = lastSession {
                AmendSessionSheet(session: session)
            }
        }
        .sheet(isPresented: $showAmendIntensitySheet) {
            if let session = lastIntensitySession {
                AmendIntensitySessionSheet(session: session)
            }
        }
        .alert("Add Preset", isPresented: $showAddPreset) {
            TextField("Minutes (1–99)", text: $newMinutes)
                .keyboardType(.numberPad)
            Button("Add") {
                if let mins = Int(newMinutes), mins >= 1, mins <= 99, !presets.contains(mins) {
                    setPresets(presets + [mins])
                }
                newMinutes = ""
            }
            Button("Cancel", role: .cancel) { newMinutes = "" }
        } message: {
            Text("Enter a duration in minutes.")
        }
        .alert("Clear \(pendingClearRange?.rawValue ?? "")?", isPresented: $showClearConfirm) {
            Button("Delete", role: .destructive) {
                performClear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(clearConfirmMessage)
        }
        .alert("Nothing to Clear", isPresented: $showNothingToClear) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No session history found in \(pendingClearRange?.rangeDescription ?? "that range").")
        }
    }
}

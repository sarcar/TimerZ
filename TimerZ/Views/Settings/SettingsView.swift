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
    @State private var showAmendSheet = false
    @State private var showAmendIntensitySheet = false

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

    private func audioCueSoundRow(label: String, id: Binding<Int>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("ID", value: id, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Button {
                AudioServicesPlaySystemSound(SystemSoundID(id.wrappedValue))
            } label: {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.indigo)
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            Form {
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
                        }
                    }
                    Toggle("Verbal Countdown", isOn: $verbalCountdownEnabled)
                }

                Section {
                    audioCueSoundRow(label: "Double Beep (Level 2)", id: $doubleBeepSoundID)
                    audioCueSoundRow(label: "Single Beep (Level 3)", id: $singleBeepSoundID)
                    audioCueSoundRow(label: "Tick (Level 4)", id: $tickSoundID)
                } header: {
                    Text("Audio Cue Sounds")
                } footer: {
                    Text("iOS system sound IDs used by the Level 2–4 audio cues (long-press the speaker icon on a timer to choose a level). Tap play to preview.")
                }

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

                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar { EditButton() }
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
        .alert("Clear all data?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) {
                try? modelContext.delete(model: Session.self)
                try? modelContext.delete(model: IntensitySession.self)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all session history and cannot be undone.")
        }
    }
}

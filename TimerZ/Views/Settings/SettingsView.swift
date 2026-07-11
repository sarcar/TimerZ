import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @AppStorage(Keys.timerPresets) private var presetsString: String = "5,10,15,25"
    @AppStorage(Keys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(Keys.soundEnabled) private var soundEnabled = true
    @AppStorage(Keys.notificationsEnabled) private var notificationsEnabled = true

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.completedAt, order: .reverse) private var sessions: [Session]

    @State private var showAddPreset = false
    @State private var newMinutes = ""
    @State private var showClearConfirm = false
    @State private var showAmendSheet = false

    private var lastSession: Session? { sessions.first }

    private var presets: [Int] {
        presetsString
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func setPresets(_ updated: [Int]) {
        presetsString = updated.map { String($0) }.joined(separator: ",")
    }

    var body: some View {
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
                }

                Section("Data") {
                    Button {
                        showAmendSheet = true
                    } label: {
                        Label("Amend Last Session", systemImage: "pencil.circle")
                    }
                    .disabled(lastSession == nil)

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
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all session history and cannot be undone.")
        }
    }
}

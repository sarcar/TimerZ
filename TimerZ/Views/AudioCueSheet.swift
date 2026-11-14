import SwiftUI

struct AudioCueSheet: View {
    @Binding var level: AudioCueLevel
    @Binding var speakMinuteMarks: Bool
    @AppStorage(Keys.minuteMarkIntervalMinutes) private var minuteMarkIntervalMinutes = 1
    @AppStorage(Keys.sayRemaining) private var sayRemaining = true

    @Environment(\.dismiss) private var dismiss

    private var minuteMarksApplicable: Bool {
        level == .everyMinute || level == .every30Seconds || level == .everySecond
    }

    private var minuteCueDescription: String {
        let cue = speakMinuteMarks ? "Speaks the time" : "Double beep"
        return minuteMarkIntervalMinutes <= 1 ? "\(cue) every minute" : "\(cue) every \(minuteMarkIntervalMinutes) min"
    }

    private func subtitle(for level: AudioCueLevel) -> String {
        switch level {
        case .muted: return "No audio cues"
        case .regular: return "Spoken countdown at key moments"
        case .everyMinute: return minuteCueDescription
        case .every30Seconds: return "\(minuteCueDescription) + single beep every 30 sec"
        case .everySecond: return "\(minuteCueDescription) + tick every second"
        }
    }

    private func icon(for level: AudioCueLevel) -> String {
        switch level {
        case .muted: return "speaker.slash.fill"
        case .regular: return "text.bubble.fill"
        case .everyMinute: return "2.circle.fill"
        case .every30Seconds: return "3.circle.fill"
        case .everySecond: return "4.circle.fill"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AudioCueLevel.allCases, id: \.self) { row in
                        AudioCueRow(
                            icon: icon(for: row),
                            title: row.shortTitle,
                            subtitle: subtitle(for: row),
                            isSelected: row == level
                        ) {
                            level = row
                            dismiss()
                        }
                    }
                }

                Section {
                    LabeledContent("Cue every") {
                        Picker("Cue every", selection: Binding(
                            get: { minuteMarkIntervalMinutes },
                            set: { newValue in
                                minuteMarkIntervalMinutes = newValue
                                if !minuteMarksApplicable {
                                    level = .everyMinute
                                }
                            }
                        )) {
                            ForEach(AudioCueLevel.minuteMarkIntervals, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    Toggle("Speak Instead of Beep", isOn: Binding(
                        get: { speakMinuteMarks },
                        set: { newValue in
                            speakMinuteMarks = newValue
                            if newValue && !minuteMarksApplicable {
                                level = .everyMinute
                            }
                        }
                    ))
                    Toggle("Say \u{201C}Remaining\u{201D}", isOn: $sayRemaining)
                } header: {
                    Text("Minute Marks")
                } footer: {
                    Text("Minute marks play at Levels 2\u{2013}4, counted by time remaining. Changing the interval or speaking while Mute or Regular is selected switches you to Level 2. \u{201C}Remaining\u{201D} applies to every spoken time, e.g. \u{201C}4 minutes\u{201D} instead of \u{201C}4 minutes remaining\u{201D}.")
                }
            }
            .navigationTitle("Audio Cues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(640)])
        .presentationDragIndicator(.visible)
    }
}

private struct AudioCueRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

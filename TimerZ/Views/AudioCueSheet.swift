import SwiftUI

struct AudioCueSheet: View {
    @Binding var level: AudioCueLevel
    @Binding var speakMinuteMarks: Bool

    @Environment(\.dismiss) private var dismiss

    private var minuteMarksApplicable: Bool {
        level == .everyMinute || level == .every30Seconds || level == .everySecond
    }

    private var minuteCueDescription: String {
        speakMinuteMarks ? "Speaks the time" : "Double beep"
    }

    private func subtitle(for level: AudioCueLevel) -> String {
        switch level {
        case .muted: return "No audio cues"
        case .regular: return "Spoken countdown at key moments"
        case .everyMinute: return "\(minuteCueDescription) every minute"
        case .every30Seconds: return "\(minuteCueDescription) every minute + single beep every 30 sec"
        case .everySecond: return "\(minuteCueDescription) every minute + tick every second"
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
                    Toggle("Speak Minute Marks", isOn: Binding(
                        get: { speakMinuteMarks },
                        set: { newValue in
                            speakMinuteMarks = newValue
                            if newValue && !minuteMarksApplicable {
                                level = .everyMinute
                            }
                        }
                    ))
                } footer: {
                    Text("Say the time instead of a double beep at each minute. Turning this on while Mute or Regular is selected switches you to Level 2.")
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

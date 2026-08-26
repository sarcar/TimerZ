import SwiftUI

struct TaskFormView: View {
    let existingTask: TimerTask?
    let onSave: (String, Int) -> Void

    @AppStorage(Keys.timerPresets) private var presetsString: String = "5,10,15,25"
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var durationMinutes: Int?
    @FocusState private var nameFocused: Bool

    init(task: TimerTask? = nil, onSave: @escaping (String, Int) -> Void) {
        self.existingTask = task
        self.onSave = onSave
        _name = State(initialValue: task?.name ?? "")
        _durationMinutes = State(initialValue: task?.durationMinutes)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (durationMinutes ?? 0) >= 1
            && (durationMinutes ?? 0) <= 999
    }

    private var presets: [Int] {
        presetsString
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task name", text: $name)
                        .focused($nameFocused)
                    TextField("Minutes (1–999)", value: $durationMinutes, format: .number)
                        .keyboardType(.numberPad)
                }

                if !presets.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presets, id: \.self) { minutes in
                                    presetPill(minutes)
                                }
                            }
                        }
                    } header: {
                        Text("Quick Fill")
                    }
                }
            }
            .navigationTitle(existingTask == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces), durationMinutes ?? 0)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { nameFocused = false }
                }
            }
            .onAppear { nameFocused = existingTask == nil }
        }
    }

    private func presetPill(_ minutes: Int) -> some View {
        let isSelected = durationMinutes == minutes
        return Button {
            durationMinutes = minutes
        } label: {
            Text("\(minutes) min")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI
import SwiftData

struct AmendIntensitySessionSheet: View {
    let session: IntensitySession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Session detail card
                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        session.completedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                    Divider()
                    Label(
                        "Focus until \(session.committedUntil.formatted(date: .omitted, time: .shortened))",
                        systemImage: "timer"
                    )
                    if session.distractionCount > 0 {
                        Divider()
                        Label(
                            "\(session.distractionCount) distraction\(session.distractionCount == 1 ? "" : "s") logged",
                            systemImage: "flag.fill"
                        )
                    }
                }
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Result toggle
                VStack(spacing: 4) {
                    Toggle(isOn: Binding(
                        get: { session.completed },
                        set: { newValue in
                            session.completed = newValue
                            try? modelContext.save()
                        }
                    )) {
                        Label(
                            session.completed ? "Completed" : "Broken",
                            systemImage: session.completed ? "checkmark.seal.fill" : "xmark.seal.fill"
                        )
                        .foregroundStyle(session.completed ? .green : .red)
                        .font(.headline)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.default, value: session.completed)
                    }
                    .toggleStyle(.switch)
                    .tint(.green)
                    .padding()
                    .background(.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("Toggle to flip the recorded outcome. Changes save instantly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Session", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()
            }
            .padding()
            .navigationTitle("Amend Intensity Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete this session?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(session)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes this Intensity session from your history.")
            }
        }
    }
}

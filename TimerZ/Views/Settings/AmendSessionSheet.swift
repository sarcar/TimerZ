import SwiftUI
import SwiftData

struct AmendSessionSheet: View {
    let session: Session

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
                        "\(session.durationSeconds / 60) min session",
                        systemImage: "timer"
                    )
                }
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Result toggle
                VStack(spacing: 4) {
                    Toggle(isOn: Binding(
                        get: { session.isWin },
                        set: { newValue in
                            session.isWin = newValue
                            try? modelContext.save()
                        }
                    )) {
                        Label(
                            session.isWin ? "Win" : "Loss",
                            systemImage: session.isWin ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(session.isWin ? .green : .red)
                        .font(.headline)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.default, value: session.isWin)
                    }
                    .toggleStyle(.switch)
                    .tint(.green)
                    .padding()
                    .background(.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("Toggle to flip the recorded result. Changes save instantly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Amend Last Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

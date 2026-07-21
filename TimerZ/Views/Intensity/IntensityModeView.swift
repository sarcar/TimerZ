import SwiftUI

private struct PendingCommitment: Identifiable {
    let id = UUID()
    let until: Date
    let isTest: Bool
}

private struct ActiveIntensitySession: Identifiable {
    let id = UUID()
    let until: Date
    let isTest: Bool
}

struct IntensityModeView: View {
    @Environment(AppState.self) private var appState

    @State private var pendingCommitment: PendingCommitment?
    @State private var activeSession: ActiveIntensitySession?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("INTENSITY MODE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(3)
                        .foregroundStyle(.secondary)
                    Text("Commit, and the path will appear.")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    focusButton(now: context.date)
                }
                .padding(.horizontal, 32)

                if appState.testModeEnabled {
                    Button {
                        pendingCommitment = PendingCommitment(until: Date().addingTimeInterval(10), isTest: true)
                    } label: {
                        Text("Test (10 sec)")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()
                Spacer()
            }
            .padding()
            .navigationTitle("Intensity")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(item: $pendingCommitment) { pending in
            IntensityCommitmentView(
                committedUntil: pending.until,
                onCommit: {
                    let until = pending.until
                    let isTest = pending.isTest
                    pendingCommitment = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        activeSession = ActiveIntensitySession(until: until, isTest: isTest)
                    }
                },
                onCancel: {
                    pendingCommitment = nil
                }
            )
        }
        .fullScreenCover(item: $activeSession) { active in
            IntensitySessionView(
                committedUntil: active.until,
                isTest: active.isTest,
                onDismiss: {
                    activeSession = nil
                }
            )
        }
    }

    private func focusButton(now: Date) -> some View {
        let until = now.addingTimeInterval(3600)
        return Button {
            pendingCommitment = PendingCommitment(until: until, isTest: false)
        } label: {
            VStack(spacing: 6) {
                Text("FOCUS")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tracking(2)
                Text("until \(until.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                LinearGradient(
                    colors: [.black, Color(red: 0.2, green: 0.05, blue: 0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel("Focus until \(until.formatted(date: .omitted, time: .shortened))")
    }
}

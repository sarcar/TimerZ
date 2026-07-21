import SwiftUI

struct IntensityCommitmentView: View {
    let committedUntil: Date
    let onCommit: () -> Void
    let onCancel: () -> Void

    private var timeString: String {
        committedUntil.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Text("Commit, and the path will appear.")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                Text("Do you commit to maintain undistracted focus until \(timeString)?")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        onCommit()
                    } label: {
                        Text("Yes, I commit")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        onCancel()
                    } label: {
                        Text("No")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

import SwiftUI

struct IntensityCommitmentView: View {
    let committedUntil: Date
    let onCommit: () -> Void
    let onCancel: () -> Void

    private static let highContrastColors: [Color] = [
        .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .red
    ]

    @State private var timeColor: Color = IntensityCommitmentView.highContrastColors.randomElement()!

    private var timeString: String {
        committedUntil.formatted(date: .omitted, time: .shortened)
    }

    private var commitmentQuestion: Text {
        Text("Do you commit to maintain undistracted focus until ")
            + Text(timeString).foregroundStyle(timeColor)
            + Text("?")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                commitmentQuestion
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        onCommit()
                    } label: {
                        Text("Commit, and the path will appear.")
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

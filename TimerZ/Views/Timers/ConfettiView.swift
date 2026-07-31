import SwiftUI

private struct ConfettiPieceModel: Identifiable {
    let id = UUID()
    let horizontalDrift: CGFloat
    let riseHeight: CGFloat
    let fallDistance: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let color: Color
    let size: CGFloat
}

private struct ConfettiMotion {
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    var rotation: Double = 0
    var opacity: Double = 1
}

private struct ConfettiPieceView: View {
    let piece: ConfettiPieceModel
    let origin: CGPoint

    @State private var trigger = false

    // Gravity-like arc: rise decelerates (eases out), fall accelerates (eases in).
    // Approximated with several linear sub-segments sampled along a t^2 curve,
    // since a plain 2-point CubicKeyframe just smoothly blends and doesn't
    // read as "thrown up, pulled down."
    private var riseDuration: Double { piece.duration * 0.35 }
    private var fallDuration: Double { piece.duration * 0.65 }
    private var peak: CGFloat { -piece.riseHeight }
    private var fallRange: CGFloat { piece.fallDistance - peak }

    private func riseOffset(_ t: CGFloat) -> CGFloat { peak * (1 - pow(1 - t, 2)) }
    private func fallOffset(_ t: CGFloat) -> CGFloat { peak + fallRange * pow(t, 2) }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size * 0.4)
            .position(origin)
            .keyframeAnimator(initialValue: ConfettiMotion(), trigger: trigger) { content, motion in
                content
                    .offset(x: motion.xOffset, y: motion.yOffset)
                    .rotationEffect(.degrees(motion.rotation))
                    .opacity(motion.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.xOffset) {
                    CubicKeyframe(piece.horizontalDrift, duration: piece.duration)
                }
                KeyframeTrack(\.yOffset) {
                    LinearKeyframe(riseOffset(0.25), duration: riseDuration / 4)
                    LinearKeyframe(riseOffset(0.5), duration: riseDuration / 4)
                    LinearKeyframe(riseOffset(0.75), duration: riseDuration / 4)
                    LinearKeyframe(riseOffset(1.0), duration: riseDuration / 4)
                    LinearKeyframe(fallOffset(0.25), duration: fallDuration / 4)
                    LinearKeyframe(fallOffset(0.5), duration: fallDuration / 4)
                    LinearKeyframe(fallOffset(0.75), duration: fallDuration / 4)
                    LinearKeyframe(fallOffset(1.0), duration: fallDuration / 4)
                }
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(piece.rotation, duration: piece.duration)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: piece.duration * 0.6)
                    LinearKeyframe(0, duration: piece.duration * 0.4)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + piece.delay + 0.03) {
                    trigger = true
                }
            }
    }
}

struct ConfettiView: View {
    private let pieces: [ConfettiPieceModel]

    init(pieceCount: Int = 40) {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .teal]
        pieces = (0..<pieceCount).map { _ in
            ConfettiPieceModel(
                horizontalDrift: CGFloat.random(in: -140...140),
                riseHeight: CGFloat.random(in: 80...180),
                fallDistance: CGFloat.random(in: 240...420),
                delay: Double.random(in: 0...0.15),
                duration: Double.random(in: 1.1...1.5),
                rotation: Double.random(in: 180...540) * (Bool.random() ? 1 : -1),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            let origin = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPieceView(piece: piece, origin: origin)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

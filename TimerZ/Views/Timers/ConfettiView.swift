import SwiftUI

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let fallDistance: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let color: Color
    let size: CGFloat
}

struct ConfettiView: View {
    @State private var animate = false

    private let pieces: [ConfettiPiece]

    init(pieceCount: Int = 60) {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .teal]
        pieces = (0..<pieceCount).map { _ in
            ConfettiPiece(
                angle: Double.random(in: 0..<360),
                distance: CGFloat.random(in: 60...160),
                fallDistance: CGFloat.random(in: 200...420),
                delay: Double.random(in: 0...0.1),
                duration: Double.random(in: 0.9...1.5),
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
                    let radians = piece.angle * .pi / 180
                    let endX = origin.x + cos(radians) * piece.distance
                    let endY = origin.y + sin(radians) * piece.distance + piece.fallDistance

                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.4)
                        .rotationEffect(.degrees(animate ? piece.rotation : 0))
                        .position(x: animate ? endX : origin.x, y: animate ? endY : origin.y)
                        .opacity(animate ? 0 : 1)
                        .animation(.easeOut(duration: piece.duration).delay(piece.delay), value: animate)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

import SwiftUI
import UIKit
import AudioToolbox

struct JogDial: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>

    @AppStorage(Keys.dialFeedbackEnabled) private var dialFeedbackEnabled = true

    @State private var minutesFloat: Double
    @State private var lastAngle: Double?

    private let degreesPerMinute = 6.0 // 360 degrees / 60 minutes

    init(minutes: Binding<Int>, range: ClosedRange<Int>) {
        _minutes = minutes
        self.range = range
        _minutesFloat = State(initialValue: Double(minutes.wrappedValue))
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let outerRadius = size / 2
            let inset: CGFloat = 24
            let innerRadius = outerRadius - inset

            ZStack {
                // Outer track shows progress into a second lap (past 60 min)
                Circle()
                    .stroke(Color.indigo.opacity(0.1), lineWidth: 10)

                if lap2Progress > 0 {
                    Circle()
                        .trim(from: 0, to: lap2Progress)
                        .stroke(Color.indigo.opacity(0.7), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .indigo.opacity(0.7), radius: 6)
                }

                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 26)
                    .padding(inset)

                Circle()
                    .trim(from: 0, to: lap1Progress)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 26, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
                    .shadow(color: .indigo.opacity(0.8), radius: 12)
                    .shadow(color: .indigo.opacity(0.5), radius: 24)

                Circle()
                    .fill(Color.indigo)
                    .frame(width: 36, height: 36)
                    .shadow(color: .indigo, radius: 10)
                    .shadow(color: .indigo.opacity(0.6), radius: 20)
                    .offset(y: -innerRadius)
                    .rotationEffect(.degrees(handleAngle))

                VStack(spacing: 2) {
                    Text("\(minutes)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.default, value: minutes)
                    Text("minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let center = CGPoint(x: size / 2, y: size / 2)
                        let vector = CGPoint(x: value.location.x - center.x, y: value.location.y - center.y)
                        var angle = atan2(vector.y, vector.x) * 180 / .pi + 90
                        if angle < 0 { angle += 360 }

                        if let last = lastAngle {
                            var delta = angle - last
                            if delta > 180 { delta -= 360 }
                            if delta < -180 { delta += 360 }

                            let deltaMinutes = delta / degreesPerMinute
                            let clampedFloat = min(max(minutesFloat + deltaMinutes, Double(range.lowerBound)), Double(range.upperBound))
                            if clampedFloat != minutesFloat {
                                let hitLimit = clampedFloat == Double(range.lowerBound) || clampedFloat == Double(range.upperBound)
                                minutesFloat = clampedFloat
                                let newInt = Int(minutesFloat.rounded())
                                if newInt != minutes {
                                    minutes = newInt
                                    tickFeedback()
                                } else if hitLimit {
                                    limitFeedback()
                                }
                            }
                        }
                        lastAngle = angle
                    }
                    .onEnded { _ in
                        lastAngle = nil
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Duration")
        .accessibilityValue("\(minutes) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = min(minutes + 1, range.upperBound)
            case .decrement: minutes = max(minutes - 1, range.lowerBound)
            @unknown default: break
            }
            minutesFloat = Double(minutes)
        }
    }

    private var lap1Progress: CGFloat { CGFloat(min(minutesFloat, 60) / 60) }
    private var lap2Progress: CGFloat { CGFloat(max(0, minutesFloat - 60) / 60) }
    private var handleAngle: Double { minutesFloat.truncatingRemainder(dividingBy: 60) * degreesPerMinute }

    private func tickFeedback() {
        guard dialFeedbackEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        AudioServicesPlaySystemSound(1157)
    }

    private func limitFeedback() {
        guard dialFeedbackEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

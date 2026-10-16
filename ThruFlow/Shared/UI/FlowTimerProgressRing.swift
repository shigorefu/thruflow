import SwiftUI

/// One continuous stroke keeps rounded outer ends without overlapping segment caps.
struct FlowTimerProgressRing: View {
    let progress: Double
    let tint: Color
    let slices: [FlowTimerRingSlice]
    let lineWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .trim(from: 0, to: clampedProgress)
            .stroke(strokeStyle, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .overlay(alignment: .top) {
                // Angular gradients wrap at twelve o'clock. Keep the initial
                // rounded cap in the first color until the ring is complete.
                if clampedProgress > 0, clampedProgress < 1, slices.count > 1,
                   let first = slices.first {
                    Circle()
                        .fill(Color(hex: first.colorHex))
                        .frame(width: lineWidth, height: lineWidth)
                        .offset(y: -lineWidth / 2)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.38), value: clampedProgress)
            .accessibilityHidden(true)
    }

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    private var strokeStyle: AnyShapeStyle {
        guard let first = slices.first, let last = slices.last else {
            return AnyShapeStyle(tint)
        }
        // Repeated stop locations create sharp color boundaries at task switches.
        var stops = [Gradient.Stop(color: Color(hex: first.colorHex), location: 0)]
        for slice in slices {
            let color = Color(hex: slice.colorHex)
            stops.append(.init(color: color, location: slice.start))
            stops.append(.init(color: color, location: slice.end))
        }
        stops.append(.init(color: Color(hex: last.colorHex), location: 1))
        return AnyShapeStyle(AngularGradient(
            gradient: Gradient(stops: stops),
            center: .center,
            startAngle: .zero,
            endAngle: .degrees(360)
        ))
    }
}

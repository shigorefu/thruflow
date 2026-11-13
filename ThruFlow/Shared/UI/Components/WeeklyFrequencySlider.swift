import SwiftUI

struct WeeklyFrequencySlider: View {
    @Binding var value: Int

    private let range = 1...7
    private let thumbDiameter: CGFloat = 36
    private let trackHeight: CGFloat = 28
    private let dotDiameter: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, thumbDiameter)
            let horizontalInset = thumbDiameter / 2
            let travelWidth = max(width - thumbDiameter, 0)
            let progress = CGFloat(clampedValue - range.lowerBound)
                / CGFloat(range.upperBound - range.lowerBound)
            let thumbX = horizontalInset + travelWidth * progress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.14))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: thumbX, height: trackHeight)

                ForEach(Array(range), id: \.self) { option in
                    Circle()
                        .fill(dotColor(for: option))
                        .frame(width: dotDiameter, height: dotDiameter)
                        .position(
                            x: horizontalInset + travelWidth * optionProgress(option),
                            y: thumbDiameter / 2
                        )
                }

                ZStack {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.16), radius: 3, y: 1)

                    Text("\(clampedValue)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.black.opacity(0.78))
                }
                .frame(width: thumbDiameter, height: thumbDiameter)
                .position(x: thumbX, y: thumbDiameter / 2)
            }
            .frame(height: thumbDiameter)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(at: gesture.location.x, width: width)
                    }
            )
            .animation(.easeOut(duration: 0.1), value: clampedValue)
        }
        .frame(height: thumbDiameter)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "週回"))
        .accessibilityValue("\(clampedValue)")
        .accessibilityAdjustableAction { area in
            switch area {
            case .increment:
                value = min(range.upperBound, clampedValue + 1)
            case .decrement:
                value = max(range.lowerBound, clampedValue - 1)
            @unknown default:
                break
            }
        }
    }

    private var clampedValue: Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private func optionProgress(_ option: Int) -> CGFloat {
        CGFloat(option - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
    }

    private func dotColor(for option: Int) -> Color {
        option <= clampedValue
            ? Color.white.opacity(0.34)
            : Color.primary.opacity(0.28)
    }

    private func updateValue(at xPosition: CGFloat, width: CGFloat) {
        let horizontalInset = thumbDiameter / 2
        let travelWidth = max(width - thumbDiameter, 1)
        let progress = min(1, max(0, (xPosition - horizontalInset) / travelWidth))
        let steps = CGFloat(range.upperBound - range.lowerBound)
        value = range.lowerBound + Int((progress * steps).rounded())
    }
}

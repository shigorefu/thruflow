#if os(macOS) || os(iOS)
import SwiftData
import SwiftUI

struct HistoryRecordProgressPreview: View {
    let measurement: TodoMeasurement
    let plannedAmount: Int?
    let currentFocusSeconds: Int
    let currentActualProgress: Int
    let addedFocusSeconds: Int
    let tint: Color

    var body: some View {
        ZStack {
            switch measurement {
            case .checkbox:
                RoundedRectangle(cornerRadius: 5)
                    .fill(tint)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
            case .focusBlocks:
                Circle()
                    .stroke(tint.opacity(0.22), lineWidth: 3)
                    .overlay {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
            case .minutes:
                Circle()
                    .fill(tint.opacity(0.16))
                    .overlay {
                        HistoryRecordProgressPie(progress: progress)
                            .fill(tint)
                    }
                    .overlay {
                        Image(systemName: "timer")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(progress > 0.52 ? Color.white : tint)
                    }
            }
        }
        .frame(width: 22, height: 22)
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }

    private var progress: Double {
        switch measurement {
        case .checkbox:
            return 1
        case .focusBlocks:
            guard let plannedAmount, plannedAmount > 0 else { return 0 }
            return min(
                BlockUnit.blocks(forFocusedSeconds: currentFocusSeconds + addedFocusSeconds)
                    / Double(plannedAmount),
                1
            )
        case .minutes:
            guard let plannedAmount, plannedAmount > 0 else { return 0 }
            let actualMinutes = currentActualProgress + addedFocusSeconds / 60
            return min(Double(actualMinutes) / Double(plannedAmount), 1)
        }
    }
}

private struct HistoryRecordProgressPie: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let value = min(max(progress, 0), 1)
        guard value > 0 else { return Path() }
        if value >= 1 { return Path(ellipseIn: rect) }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * value),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#endif

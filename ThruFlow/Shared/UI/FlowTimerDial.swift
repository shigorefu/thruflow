import SwiftUI

/// The shared timer dial used by the real Flow player and presentation-only previews.
/// Callers provide timer state; this view never starts a timer or writes application data.
struct FlowTimerDial: View {
    enum Style {
        case mobile
        case dashboard

        var size: CGFloat {
            switch self {
            case .mobile: 164
            case .dashboard: 158
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .mobile: 11
            case .dashboard: 10
            }
        }

        var contentSpacing: CGFloat {
            switch self {
            case .mobile: 3
            case .dashboard: 5
            }
        }

        var timerFont: Font {
            switch self {
            case .mobile:
                .system(size: 34, weight: .semibold, design: .rounded)
            case .dashboard:
                .system(.title, design: .rounded).weight(.bold)
            }
        }

        var trackColor: Color {
            switch self {
            case .mobile: Color.secondary.opacity(0.13)
            case .dashboard: Color.primary.opacity(0.08)
            }
        }

        var progressAnimation: Animation? {
            switch self {
            case .mobile: .linear(duration: 0.25)
            case .dashboard: nil
            }
        }
    }

    let progress: Double
    let tint: Color
    let eyebrow: String
    let timeText: String
    let footer: String
    let style: Style

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(style.trackColor, lineWidth: style.lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? nil : style.progressAnimation,
                    value: clampedProgress
                )

            VStack(spacing: style.contentSpacing) {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(timeText)
                    .font(style.timerFont)
                    .monospacedDigit()

                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: style.size, height: style.size)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}

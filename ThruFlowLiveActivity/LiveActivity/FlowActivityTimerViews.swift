#if os(iOS)
import Foundation
import SwiftUI

struct FlowActivityIdentity: View {
    let state: FlowActivityAttributes.ContentState
    let iconSize: CGFloat
    let width: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Text(state.presentationEmoji)
                .font(.system(size: iconSize * 0.62))
                .frame(width: iconSize, height: iconSize)
                .background(
                    state.tintColor.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: iconSize * 0.24)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(state.presentationTitle)
                    .font(.headline)
                    .lineLimit(1)

                if !state.presentationAreaName.isEmpty {
                    Text(state.presentationAreaName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)
        }
        .frame(width: width, alignment: .leading)
    }
}

struct FlowActivityClock: View {
    let state: FlowActivityAttributes.ContentState
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            FlowActivityTimeLabel(state: state)
                .font(.title2.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
        }
        .frame(width: width, alignment: .trailing)
    }
}

struct FlowActivityTimeLabel: View {
    let state: FlowActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text(
                FlowLiveActivityFormatter.timeText(
                    seconds: state.remainingSeconds,
                    allowsOvertime: true
                )
            )
        } else {
            runningTime
        }
    }

    @ViewBuilder
    private var runningTime: some View {
        if state.remainingSeconds < 0 {
            (
                Text(verbatim: "+")
                + Text(
                    timerInterval: state.overtimeRange,
                    countsDown: false,
                    showsHours: false
                )
            )
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        } else {
            Text(
                timerInterval: state.timerRange,
                countsDown: true,
                showsHours: false
            )
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        }
    }
}

struct FlowActivityProgressView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: FlowActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isPaused {
                ProgressView(value: state.progress)
                    .labelsHidden()
            } else {
                ProgressView(
                    timerInterval: state.timerRange,
                    countsDown: state.progressCountsDown
                )
                .labelsHidden()
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.38),
            value: state.plannedEndAt
        )
    }
}

struct FlowActivityCircularProgress: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: FlowActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isPaused {
                ProgressView(value: state.progress)
            } else {
                ProgressView(
                    timerInterval: state.timerRange,
                    countsDown: state.minimalProgressCountsDown
                ) {
                    EmptyView()
                } currentValueLabel: {
                    Text(timerInterval: state.timerRange, countsDown: true, showsHours: false)
                        .monospacedDigit()
                }
            }
        }
        .progressViewStyle(.circular)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.38),
            value: state.plannedEndAt
        )
        .accessibilityLabel(state.statusTitle)
    }
}

extension FlowActivityAttributes.ContentState {
    var tintColor: Color {
        Color(productHex: timerKind == .breakTime ? "#8E8E93" : areaColorHex)
    }
}
#endif

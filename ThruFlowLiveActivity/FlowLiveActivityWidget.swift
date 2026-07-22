import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct FlowLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowActivityAttributes.self) { context in
            FlowLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.86))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(FlowLiveActivityView.openURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FlowActivityTaskLabel(state: context.state, showsDirection: false)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.statusTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        FlowActivityTimeLabel(state: context.state)
                            .font(.title3.monospacedDigit().weight(.semibold))
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 6) {
                        Text(context.state.modeName)
                            .font(.caption.weight(.semibold))
                        if !context.state.directionName.isEmpty {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(context.state.directionEmoji) \(context.state.directionName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        FlowActivityProgressView(state: context.state)
                            .tint(context.state.tintColor)
                        FlowActivityActions(state: context.state, compact: true)
                    }
                }
            } compactLeading: {
                Text(context.state.taskEmoji)
                    .accessibilityLabel(context.state.taskTitle)
            } compactTrailing: {
                FlowActivityTimeLabel(state: context.state)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 42)
            } minimal: {
                FlowActivityCircularProgress(state: context.state)
                    .tint(context.state.tintColor)
                    .padding(3)
            }
            .keylineTint(context.state.tintColor)
            .widgetURL(FlowLiveActivityView.openURL)
        }
    }
}

private struct FlowLockScreenView: View {
    let context: ActivityViewContext<FlowActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(context.state.taskEmoji)
                    .font(.system(size: 32))
                    .frame(width: 48, height: 48)
                    .background(context.state.tintColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))

                FlowActivityTaskLabel(state: context.state, showsDirection: true)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(context.state.statusTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    FlowActivityTimeLabel(state: context.state)
                        .font(.title2.monospacedDigit().weight(.bold))
                    Text(context.state.modeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            FlowActivityProgressView(state: context.state)
                .tint(context.state.tintColor)

            FlowActivityActions(state: context.state, compact: false)
        }
        .padding(16)
        .accessibilityElement(children: .contain)
    }
}

private struct FlowActivityTaskLabel: View {
    let state: FlowActivityAttributes.ContentState
    let showsDirection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.taskTitle)
                .font(.headline)
                .lineLimit(1)
            if showsDirection, !state.directionName.isEmpty {
                Text("\(state.directionEmoji) \(state.directionName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct FlowActivityTimeLabel: View {
    let state: FlowActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text(FlowLiveActivityFormatter.timeText(seconds: state.remainingSeconds))
        } else {
            Text(timerInterval: state.timerRange, countsDown: true, showsHours: false)
        }
    }
}

private struct FlowActivityProgressView: View {
    let state: FlowActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            ProgressView(value: state.progress)
        } else {
            ProgressView(
                timerInterval: state.timerRange,
                countsDown: state.progressCountsDown
            )
        }
    }
}

private struct FlowActivityCircularProgress: View {
    let state: FlowActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isPaused {
                ProgressView(value: state.progress)
            } else {
                ProgressView(
                    timerInterval: state.timerRange,
                    countsDown: state.progressCountsDown
                )
            }
        }
        .progressViewStyle(.circular)
        .accessibilityLabel(state.statusTitle)
    }
}

private struct FlowActivityActions: View {
    let state: FlowActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 20 : 28) {
            Button(intent: ToggleFlowPauseIntent()) {
                Label(
                    state.isPaused ? String(localized: "再開") : String(localized: "一時停止"),
                    systemImage: state.isPaused ? "play.fill" : "pause.fill"
                )
            }
            .buttonStyle(.plain)
            .labelStyle(FlowActivityActionLabelStyle(compact: compact))

            Button(intent: FinishFlowIntent()) {
                Label(String(localized: "終了"), systemImage: "stop.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .labelStyle(FlowActivityActionLabelStyle(compact: compact))

            Link(destination: FlowLiveActivityView.openURL) {
                Label(String(localized: "アプリを開く"), systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.plain)
            .labelStyle(FlowActivityActionLabelStyle(compact: compact))
        }
        .font(compact ? .body : .subheadline.weight(.semibold))
    }
}

private struct FlowActivityActionLabelStyle: LabelStyle {
    let compact: Bool

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if compact {
            configuration.icon
        } else {
            HStack(spacing: 6) {
                configuration.icon
                configuration.title
            }
        }
    }
}

private enum FlowLiveActivityView {
    static let openURL = URL(string: "thruflow://flow")!
}

private extension FlowActivityAttributes.ContentState {
    var tintColor: Color {
        Color(flowHex: timerKind == .breakTime ? "#8E8E93" : directionColorHex)
    }
}

private extension Color {
    init(flowHex: String) {
        let normalized = flowHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(normalized, radix: 16) ?? 0x007AFF
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

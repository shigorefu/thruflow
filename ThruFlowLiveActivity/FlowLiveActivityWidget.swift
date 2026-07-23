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
                    FlowActivityIdentity(
                        state: context.state,
                        iconSize: 36,
                        width: 172
                    )
                    .padding(.leading, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    FlowActivityClock(state: context.state, width: 88)
                        .padding(.trailing, 8)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        FlowActivityProgressView(state: context.state)
                            .tint(context.state.tintColor)
                        FlowActivityTransportControls(state: context.state)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Text(context.state.taskEmoji)
                    .font(.caption)
                    .accessibilityLabel(context.state.taskTitle)
            } compactTrailing: {
                FlowActivityTimeLabel(state: context.state)
                    .font(.caption2.monospacedDigit().weight(.semibold))
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
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                FlowActivityIdentity(
                    state: context.state,
                    iconSize: 44,
                    width: 188
                )

                Spacer(minLength: 6)

                FlowActivityClock(state: context.state, width: 86)
            }

            FlowActivityProgressView(state: context.state)
                .tint(context.state.tintColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .accessibilityElement(children: .contain)
    }
}

private struct FlowActivityIdentity: View {
    let state: FlowActivityAttributes.ContentState
    let iconSize: CGFloat
    let width: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Text(state.taskEmoji)
                .font(.system(size: iconSize * 0.62))
                .frame(width: iconSize, height: iconSize)
                .background(
                    state.tintColor.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: iconSize * 0.24)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(state.taskTitle)
                    .font(.headline)
                    .lineLimit(1)

                if !state.directionName.isEmpty {
                    Text(state.directionName)
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

private struct FlowActivityClock: View {
    let state: FlowActivityAttributes.ContentState
    let width: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            FlowActivityTimeLabel(state: state)
                .font(.title2.monospacedDigit().weight(.bold))
                .lineLimit(1)

            Text("\(state.statusTitle) · \(state.modeName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .trailing)
    }
}

private struct FlowActivityTimeLabel: View {
    let state: FlowActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text(FlowLiveActivityFormatter.timeText(seconds: state.remainingSeconds))
        } else {
            Text(timerInterval: state.timerRange, countsDown: true, showsHours: false)
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        }
    }
}

private struct FlowActivityProgressView: View {
    let state: FlowActivityAttributes.ContentState

    var body: some View {
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

private struct FlowActivityTransportControls: View {
    let state: FlowActivityAttributes.ContentState

    private var canSeek: Bool {
        state.timerKind == .focus
    }

    var body: some View {
        HStack(spacing: 20) {
            Button(intent: SeekFlowBackwardIntent()) {
                actionIcon("gobackward.minus")
            }
            .disabled(!canSeek)
            .opacity(canSeek ? 1 : 0.35)
            .accessibilityLabel(String(localized: "ブロックを短縮"))

            Button(intent: ToggleFlowPauseIntent()) {
                actionIcon(
                    state.isPaused ? "play.fill" : "pause.fill",
                    foreground: .white,
                    background: state.tintColor
                )
            }
            .accessibilityLabel(state.isPaused ? String(localized: "再開") : String(localized: "一時停止"))

            Button(intent: SeekFlowForwardIntent()) {
                actionIcon("goforward.plus")
            }
            .disabled(!canSeek)
            .opacity(canSeek ? 1 : 0.35)
            .accessibilityLabel(String(localized: "ブロックを延長"))
        }
        .buttonStyle(.plain)
    }

    private func actionIcon(
        _ systemName: String,
        foreground: Color = .secondary,
        background: Color = .clear
    ) -> some View {
        Image(systemName: systemName)
            .font(.callout.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: 38, height: 38)
            .background(background, in: Circle())
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

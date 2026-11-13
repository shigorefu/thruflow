#if os(iOS)
import ActivityKit
import Foundation
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
                Text(context.state.presentationEmoji)
                    .font(.caption)
                    .frame(width: 20, height: 20)
                    .accessibilityLabel(context.state.presentationTitle)
            } compactTrailing: {
                FlowActivityTimeLabel(state: context.state)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 48, alignment: .trailing)
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

private enum FlowLiveActivityView {
    static let openURL = URL(string: "thruflow://flow")!
}
#endif

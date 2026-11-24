#if os(iOS)
import SwiftUI
import WidgetKit

struct FlowLockScreenView: View {
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
#endif

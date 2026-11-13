#if os(iOS)
import AppIntents
import SwiftUI

struct FlowActivityTransportControls: View {
    let state: FlowActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 20) {
            Button(intent: SeekFlowBackwardIntent()) {
                actionIcon("gobackward.5")
            }
            .accessibilityLabel(String(localized: "残り時間を5分短縮"))

            Button(intent: ToggleFlowPauseIntent()) {
                actionIcon(
                    state.isPaused ? "play.fill" : "pause.fill",
                    foreground: .white,
                    background: state.tintColor
                )
            }
            .accessibilityLabel(state.isPaused ? String(localized: "再開") : String(localized: "一時停止"))

            Button(intent: SeekFlowForwardIntent()) {
                actionIcon("goforward.5")
            }
            .accessibilityLabel(String(localized: "残り時間を5分延長"))
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
#endif

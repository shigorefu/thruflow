#if os(watchOS)
import Foundation
import SwiftUI

struct WatchTimerRing: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let now: Date
    let size: CGFloat
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.2), lineWidth: 8)
            FlowTimerProgressRing(
                progress: activeFlowStore.phaseProgress(now: now),
                tint: tint,
                slices: activeFlowStore.timerRingSlices(now: now),
                lineWidth: 8
            )

            VStack(spacing: 0) {
                Text(activeFlowStore.phase.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(timerText(now: now))
                    .font(.system(size: max(18, size * 0.24), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(activeFlowStore.selectedMode.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func timerText(now: Date) -> String {
        activeFlowStore.timerState == nil
            ? activeFlowStore.selectedMode.compactDurationText
            : activeFlowStore.remainingText(now: now)
    }
}
#endif

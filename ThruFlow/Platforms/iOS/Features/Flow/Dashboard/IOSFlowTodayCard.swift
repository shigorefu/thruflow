#if os(iOS)
import SwiftUI

struct IOSFlowTodayCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let snapshot: FlowDashboardSnapshot?
    let isActive: Bool
    let mode: FlowMode
    let breakStyle: FlowStreamBreakStyle
    let breakInteraction: FlowBreakInteraction?
    let isVisible: Bool
    let onOpenHistory: (IOSFlowTimelineSelection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "今日のFlow"))
                        .font(.headline)
                    Text(snapshot?.date ?? .now, format: .dateTime.month().day().weekday())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                if let snapshot {
                    metric(value: focusText(snapshot.totalFocusSeconds), label: String(localized: "集中時間"))
                    metric(value: blockText(snapshot.blocks), label: String(localized: "ブロック"))
                }
            }

            VStack(spacing: 12) {
                if let snapshot {
                    IOSFlowStreamView(
                        snapshot: snapshot,
                        isActive: isActive,
                        mode: mode,
                        breakStyle: breakStyle,
                        breakInteraction: breakInteraction,
                        isRenderingEnabled: isVisible
                    )
                    .frame(height: 142)
                    .background {
                        modeSurfaceTint
                            .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: mode)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    IOSFlowTimelineView(
                        snapshot: snapshot,
                        isVisible: isVisible,
                        onOpenHistory: onOpenHistory
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 190)
                }
            }
            .productContentFade(on: snapshot != nil)
        }
        .padding(14)
        .frame(minHeight: nil, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var modeSurfaceTint: Color {
        switch mode {
        case .sprint, .adaptive:
            Color.orange.opacity(0.035)
        case .twentyFiveFive:
            Color.cyan.opacity(0.035)
        case .fiftyTen:
            Color.indigo.opacity(0.045)
        }
    }

    private func focusText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes >= 60 ? "\(minutes / 60):\(String(format: "%02d", minutes % 60))" : "\(minutes)\(String(localized: "分"))"
    }

    private func blockText(_ blocks: Double) -> String {
        blocks.formatted(.number.precision(.fractionLength(blocks.rounded() == blocks ? 0 : 1)))
    }
}
#endif

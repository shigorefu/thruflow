#if os(macOS)
import SwiftUI

struct FlowDashboardStage<Timeline: View>: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @EnvironmentObject private var settings: AppSettings

    let snapshot: FlowDashboardSnapshot
    let isLoaded: Bool
    let isVisible: Bool
    @ViewBuilder let timeline: (Date) -> Timeline

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "今日のFlow"))
                        .font(.title2.weight(.semibold))
                    Text(dateText(snapshot.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Group {
                    if isLoaded {
                        metric(value: focusText(snapshot.totalFocusSeconds), label: String(localized: "集中時間"))
                        metric(value: blockText(snapshot.blocks), label: String(localized: "ブロック"))
                        metric(value: "\(snapshot.flowCount)", label: String(localized: "集中回数"))
                    }
                }
                .productContentFade(on: isLoaded)
            }

            streamSurface
            Group {
                if isLoaded {
                    TimelineView(FlowDashboardTimelineSchedule(
                        isVisible: isVisible,
                        showsPlannedEnd: settings.showsTimelinePlannedEnd,
                        timerState: activeFlowStore.timerState
                    )) { tick in
                        timeline(isVisible ? tick.date : .now)
                    }
                } else {
                    FlowDashboardLoadingView()
                }
            }
            .productContentFade(on: isLoaded)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var streamSurface: some View {
        ZStack(alignment: .bottomLeading) {
            FlowStreamView(
                blocks: snapshot.blocks,
                flowCount: snapshot.flowCount,
                palette: snapshot.palette,
                paletteWeights: snapshot.paletteWeights,
                dailySeed: snapshot.dailyVisualSeed,
                isActive: activeFlowStore.phase == .focusing,
                mode: activeFlowStore.selectedMode,
                breakStyle: activeFlowStore.flowStreamBreakStyle,
                breakInteraction: activeFlowStore.flowBreakInteraction,
                isRenderingEnabled: isVisible && isLoaded
            )

            if isLoaded && snapshot.totalFocusSeconds == 0 {
                Text(String(localized: "Flowを始めると、今日のフローがここから育ちます"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .frame(minHeight: 185, idealHeight: 200, maxHeight: 215)
        .background(modeSurfaceTint)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var modeSurfaceTint: Color {
        switch activeFlowStore.selectedMode {
        case .sprint, .adaptive:
            Color.orange.opacity(0.035)
        case .twentyFiveFive:
            Color.cyan.opacity(0.035)
        case .fiftyTen:
            Color.indigo.opacity(0.045)
        }
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).month(.wide).day().weekday(.wide))
    }

    private func blockText(_ blocks: Double) -> String {
        let rounded = (blocks * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))" : String(format: "%.1f", rounded)
    }
}

func focusText(_ seconds: Int) -> String {
    let hours = seconds / 3_600
    let minutes = (seconds % 3_600) / 60
    return hours > 0 ? String(localized: "\(hours)時間\(minutes)分") : String(localized: "\(minutes)分")
}
#endif

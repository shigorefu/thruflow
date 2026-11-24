#if os(iOS)
import SwiftUI

struct IOSStatisticsTrendCard: View {
    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let points: [StatisticsTrendPoint]
    let today: Date
    var compact = false

    var body: some View {
        IOSStatisticsAnalysisCard(
            title: String(localized: "集中の質"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク"),
            systemImage: "chart.xyaxis.line",
            compact: compact,
            accessory: { IOSStatisticsModePicker(selection: $mode) }
        ) {
            StatisticsTrendPlot(
                mode: mode, period: period, points: points, today: today,
                height: compact ? 83 : 220, compact: compact
            )
        }
    }
}
#endif

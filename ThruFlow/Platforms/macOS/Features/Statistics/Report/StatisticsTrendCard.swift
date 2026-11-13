#if os(macOS)
import SwiftUI

struct StatisticsTrendCard: View {
    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let points: [StatisticsTrendPoint]
    let today: Date
    let compact: Bool

    var body: some View {
        StatisticsAnalysisCard(
            title: String(localized: "集中の質"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク"),
            systemImage: "chart.xyaxis.line",
            compact: compact
        ) {
            StatisticsModePicker(selection: $mode, width: compact ? 108 : 180)
        } content: {
            StatisticsTrendPlot(
                mode: mode, period: period, points: points, today: today, height: compact ? 94 : 220, compact: compact
            )
        }
    }
}
#endif

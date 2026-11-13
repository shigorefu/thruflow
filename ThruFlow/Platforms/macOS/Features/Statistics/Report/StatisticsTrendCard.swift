#if os(macOS)
import SwiftUI

struct StatisticsTrendCard: View {
    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let points: [StatisticsTrendPoint]
    let today: Date

    var body: some View {
        StatisticsCard(
            title: String(localized: "傾向"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク"),
            headerAccessory: { StatisticsModePicker(selection: $mode) }
        ) {
            StatisticsTrendPlot(mode: mode, period: period, points: points, today: today, height: 220)
        }
    }
}
#endif

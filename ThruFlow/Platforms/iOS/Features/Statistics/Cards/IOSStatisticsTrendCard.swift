#if os(iOS)
import SwiftUI

struct IOSStatisticsTrendCard: View {
    @Binding var mode: StatisticsMode
    let period: StatisticsPeriod
    let points: [StatisticsTrendPoint]
    let today: Date

    var body: some View {
        IOSStatisticsCard(
            title: String(localized: "傾向"),
            subtitle: mode == .flow ? String(localized: "集中時間") : String(localized: "完了タスク"),
            headerAccessory: { IOSStatisticsModePicker(selection: $mode) }
        ) {
            StatisticsTrendPlot(mode: mode, period: period, points: points, today: today, height: 210)
        }
    }
}
#endif

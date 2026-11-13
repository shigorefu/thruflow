#if os(iOS)
import SwiftUI

struct IOSStatisticsDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let day: IOSStatisticsContributionDay
    let onOpenHistory: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(day.date.formatted(
                    .dateTime.locale(locale).year().month(.wide).day().weekday(.wide)
                ))
                .font(.headline)

                HStack(spacing: 10) {
                    dayMetric(String(localized: "集中時間"), IOSStatisticsFormatting.duration(day.focusedSeconds))
                    dayMetric(String(localized: "集中回数"), "\(day.flowCount)")
                    dayMetric(String(localized: "完了タスク"), "\(day.completedTaskCount)")
                }

                Button {
                    dismiss()
                    onOpenHistory()
                } label: {
                    Label(String(localized: "履歴"), systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .iosCenteredNavigationTitle(String(localized: "Dots"))
        }
    }

    private func dayMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
#endif

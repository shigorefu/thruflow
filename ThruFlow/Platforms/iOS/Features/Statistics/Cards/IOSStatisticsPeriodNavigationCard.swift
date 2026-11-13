#if os(iOS)
import SwiftUI

struct IOSStatisticsPeriodNavigationCard: View {
    @Binding var selection: StatisticsPeriod?

    let usesCustomRange: Bool
    let periodTitle: String
    let canMoveToNextPeriod: Bool
    let onCustomRange: () -> Void
    let onAnchorPicker: () -> Void
    let onToday: () -> Void
    let onMovePeriod: (Int) -> Void

    var body: some View {
        IOSStatisticsCard {
            VStack(spacing: 14) {
                ZStack {
                    Picker(String(localized: "統計期間"), selection: $selection) {
                        ForEach(StatisticsPeriod.allCases) { period in
                            Text(period.displayName).tag(Optional(period))
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 210)

                    HStack {
                        Spacer()
                        Button {
                            onCustomRange()
                        } label: {
                            Image(systemName: "calendar.badge.clock")
                        }
                        .buttonStyle(.bordered)
                        .tint(usesCustomRange ? Color.accentColor : nil)
                        .accessibilityLabel(String(localized: "期間を指定"))
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        onMovePeriod(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "前へ"))

                    Button {
                        onAnchorPicker()
                    } label: {
                        Text(periodTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "期間を指定"))

                    Button(String(localized: "今日"), action: onToday)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button {
                        onMovePeriod(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveToNextPeriod)
                    .accessibilityLabel(String(localized: "次へ"))
                }
            }
        }
    }
}
#endif

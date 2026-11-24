#if os(iOS)
import SwiftUI

struct IOSHistoryMonthView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar

    @Binding var selectedDate: Date
    let interval: DateInterval
    let items: [HistoryCalendarItem]
    let onNavigatePeriod: (Int) -> Void
    let onSelect: (HistoryCalendarItem) -> Void

    var body: some View {
        let date = selectedDate
        let dayItems = calendarItems(on: date, from: items)
        ScrollView {
            LazyVStack(spacing: 0) {
                IOSHistoryMonthGrid(
                    interval: interval,
                    items: items,
                    selectedDate: $selectedDate
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .iosHorizontalPeriodSwipe { offset in
                    onNavigatePeriod(offset)
                }

                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "この日の記録"))
                        .font(.headline)
                    Text(date, format: .dateTime.month().day().weekday(.wide))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                IOSHistoryChronologicalTimeline(
                    items: dayItems,
                    gapInterval: HistoryCalendarRange.day.interval(
                        containing: date,
                        calendar: calendar,
                        dayBoundary: dayBoundary
                    ),
                    isEmbedded: true,
                    onSelect: onSelect
                )
            }
        }
    }

    private func calendarItems(
        on date: Date,
        from items: [HistoryCalendarItem]
    ) -> [HistoryCalendarItem] {
        let interval = HistoryCalendarRange.day.interval(
            containing: date,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        return items.filter {
            $0.startedAt < interval.end && $0.endedAt > interval.start
        }
    }
}
#endif

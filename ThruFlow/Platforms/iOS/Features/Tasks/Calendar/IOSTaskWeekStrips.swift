#if os(iOS)
import SwiftUI

struct IOSWeekDateStrip: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let snapshot: TaskCalendarSnapshot?
    let filter: TaskCalendarFilter
    let searchQuery: DatabaseSearchQuery

    var body: some View {
        IOSScrollablePeriodStrip(
            selectedDate: $selectedDate,
            unit: .day,
            visibleItemCount: 7,
            spacing: 5,
            height: 55
        ) { date, isSelected in
            Button {
                selectedDate = calendar.startOfDay(for: date)
            } label: {
                VStack(spacing: 4) {
                    Text(date.formatted(.dateTime.locale(locale).weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                    Text("\(calendar.component(.day, from: date))")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    HStack(spacing: 2) {
                        ForEach(
                            snapshot?.indicatorColors(
                                on: date,
                                filter: filter,
                                matching: searchQuery
                            ) ?? [],
                            id: \.self
                        ) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 55)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

}

struct IOSWeekCardStrip: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let snapshot: TaskCalendarSnapshot?
    let filter: TaskCalendarFilter
    let searchQuery: DatabaseSearchQuery

    var body: some View {
        IOSScrollablePeriodStrip(
            selectedDate: $selectedDate,
            unit: .week,
            visibleItemCount: 3,
            spacing: 6,
            height: 58
        ) { anchor, isSelected in
            let dates = weekDates(containing: anchor)

            Button {
                selectedDate = calendar.startOfDay(for: anchor)
            } label: {
                VStack(spacing: 3) {
                    Text(monthText(for: dates))
                        .font(.caption.weight(.semibold))
                    Text(dayRangeText(for: dates))
                        .font(.body.monospacedDigit().weight(.semibold))

                    HStack(spacing: 2) {
                        ForEach(
                            snapshot?.indicatorColors(
                                inWeekContaining: anchor,
                                filter: filter,
                                matching: searchQuery
                            ) ?? [],
                            id: \.self
                        ) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private func weekDates(containing date: Date) -> [Date] {
        TaskCalendarBuilder(calendar: calendar).dates(for: .sevenDays, anchoredAt: date)
    }


    private func monthText(for dates: [Date]) -> String {
        guard let first = dates.first else { return "" }
        return first.formatted(.dateTime.locale(locale).month(.abbreviated))
    }

    private func dayRangeText(for dates: [Date]) -> String {
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(calendar.component(.day, from: first))–\(calendar.component(.day, from: last))"
    }

    private func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }
}
#endif

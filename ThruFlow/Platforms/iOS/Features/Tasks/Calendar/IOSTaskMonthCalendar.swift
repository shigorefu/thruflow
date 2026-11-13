#if os(iOS)
import SwiftUI

struct IOSTaskMonthCalendar: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let snapshot: TaskCalendarSnapshot
    let filter: TaskCalendarFilter
    let searchQuery: DatabaseSearchQuery

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 7
    )

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(selectedDate.formatted(.dateTime.locale(locale).year().month(.wide)))
                    .font(.headline)

                Spacer()

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar), id: \.self) {
                    Text($0)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDates, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
        let colors = snapshot.indicatorColors(
            on: date,
            filter: filter,
            matching: searchQuery,
            limit: 3
        )

        return Button {
            selectedDate = calendar.startOfDay(for: date)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.callout.monospacedDigit())

                HStack(spacing: 2) {
                    ForEach(colors, id: \.self) { colorHex in
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .foregroundStyle(isSelected ? Color.white : isCurrentMonth ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isCurrentMonth ? 1 : 0.5)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var monthDates: [Date] {
        TaskCalendarBuilder(calendar: calendar).dates(for: .month, anchoredAt: selectedDate)
    }

    private func moveMonth(by value: Int) {
        guard let date = calendar.date(byAdding: .month, value: value, to: selectedDate) else {
            return
        }
        selectedDate = calendar.startOfDay(for: date)
    }
}
#endif

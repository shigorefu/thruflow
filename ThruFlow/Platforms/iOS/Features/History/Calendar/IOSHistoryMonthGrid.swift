#if os(iOS)
import SwiftUI

struct IOSHistoryMonthGrid: View {
    let interval: DateInterval
    let items: [HistoryCalendarItem]
    @Binding var selectedDate: Date

    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(selectedDate, format: .dateTime.year().month(.wide))
                    .font(.headline)

                Spacer(minLength: 0)

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(String(localized: "前へ"))

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel(String(localized: "次へ"))
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDates, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 5) {
                            Text(verbatim: String(calendar.component(.day, from: date)))
                                .font(.subheadline.weight(isSelected || calendar.isDateInToday(date) ? .bold : .regular))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .frame(width: 30, height: 30)
                                .background(
                                    isSelected ? Color.accentColor : Color.clear,
                                    in: Circle()
                                )

                            HStack(spacing: 2) {
                                ForEach(colors(on: date).prefix(3), id: \.self) { colorHex in
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func moveMonth(by value: Int) {
        selectedDate = calendar.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
    }

    private var monthDates: [Date] {
        guard let month = calendar.dateInterval(of: .month, for: interval.start),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        let lastDay = month.end.addingTimeInterval(-1)
        let lastWeekEnd = calendar.dateInterval(of: .weekOfYear, for: lastDay)?.end ?? month.end
        let count = max(0, calendar.dateComponents([.day], from: firstWeek.start, to: lastWeekEnd).day ?? 0)
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private func colors(on date: Date) -> [String] {
        var seen = Set<String>()
        return items.compactMap { item in
            guard calendar.isDate(item.startedAt, inSameDayAs: date), item.kind == .flow else { return nil }
            return seen.insert(item.colorHex).inserted ? item.colorHex : nil
        }
    }
}
#endif

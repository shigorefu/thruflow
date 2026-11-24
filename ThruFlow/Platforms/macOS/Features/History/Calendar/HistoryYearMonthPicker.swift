#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryYearMonthPicker: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    var maximumDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    Button {
                        select(month: month)
                    } label: {
                        Text(verbatim: CalendarMonthLabels.title(for: month, calendar: calendar, locale: locale))
                            .font(.callout.weight(month == selectedMonth ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .foregroundStyle(month == selectedMonth ? Color.white : Color.primary)
                            .background(month == selectedMonth ? Color.accentColor : Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSelect(month: month))
                    .opacity(canSelect(month: month) ? 1 : 0.45)
                    .accessibilityLabel(Text(verbatim: CalendarMonthLabels.accessibilityLabel(
                        for: month, year: selectedYear, calendar: calendar, locale: locale
                    )))
                    .accessibilityAddTraits(month == selectedMonth ? .isSelected : [])
                }
            }
        }
    }

    private var selectedYear: Int {
        calendar.component(.year, from: selectedDate)
    }

    private var selectedMonth: Int {
        calendar.component(.month, from: selectedDate)
    }

    private func select(month: Int) {
        guard canSelect(month: month) else { return }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = selectedYear
        components.month = month
        components.day = 1
        if let date = components.date {
            selectedDate = calendar.startOfDay(for: date)
        }
    }

    private func canSelect(month: Int) -> Bool {
        guard let maximumDate else { return true }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = selectedYear
        components.month = month
        components.day = 1
        guard let monthDate = components.date,
              let maximumMonth = calendar.dateInterval(of: .month, for: maximumDate)?.start else {
            return true
        }
        return monthDate <= maximumMonth
    }
}
#endif

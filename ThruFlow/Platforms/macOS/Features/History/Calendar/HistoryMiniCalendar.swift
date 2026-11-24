#if os(macOS)
import SwiftData
import SwiftUI

enum HistoryMiniCalendarIndicatorSource {
    case flowHistory
    case filteredFlowHistory(Set<AreaType>)
    case statistics([StatisticsCalendarIndicator])
    case tasks(TaskCalendarFilter)
}

struct StatisticsCalendarIndicator: Identifiable {
    let date: Date
    let colorHex: String

    var id: Date { date }
}

private struct HistoryCalendarFlowIndicators: View {
    @Environment(\.calendar) private var calendar

    let items: [HistoryCalendarItem]
    let date: Date
    var maximumVisibleCount = 4

    private var dayItems: [HistoryCalendarItem] {
        items.filter {
            $0.kind == .flow && calendar.isDate($0.startedAt, inSameDayAs: date)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(dayItems.prefix(maximumVisibleCount))) { item in
                Circle()
                    .fill(Color(hex: item.colorHex))
                    .frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "集中記録"))
    }
}

struct HistoryMiniCalendar: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    var selectionMode: HistoryMiniCalendarSelectionMode = .day
    var indicatorSource: HistoryMiniCalendarIndicatorSource = .flowHistory
    var taskSnapshot: TaskCalendarSnapshot?
    var historySessions: [FlowSession] = []
    var onDropPayload: ((String, Date) -> Bool)?
    var maximumDate: Date?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: selectionMode == .week ? 0 : 2), count: 7)
    }

    static func displayedInterval(containing date: Date, calendar: Calendar) -> DateInterval? {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start),
              let end = calendar.date(byAdding: .day, value: 42, to: firstWeek.start) else { return nil }
        return DateInterval(start: firstWeek.start, end: end)
    }

    private var displayedInterval: DateInterval? {
        Self.displayedInterval(containing: selectedDate, calendar: calendar)
    }

    private var monthDays: [Date] {
        guard let displayedInterval else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: displayedInterval.start) }
    }

    private var historyItems: [HistoryCalendarItem] {
        guard showsFlowHistoryIndicators, let displayedInterval, !historySessions.isEmpty else {
            return []
        }
        return HistoryCalendarBuilder(calendar: calendar).build(
            interval: displayedInterval,
            sessions: historySessions,
            breaks: []
        ).items
    }

    private var showsFlowHistoryIndicators: Bool {
        switch indicatorSource {
        case .flowHistory, .filteredFlowHistory:
            true
        case .statistics, .tasks:
            false
        }
    }

    var body: some View {
        let flowItems = historyItems

        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(monthDays, id: \.self) { date in
                    Button {
                        selectedDate = calendar.startOfDay(for: date)
                    } label: {
                        calendarDayLabel(for: date, flowItems: flowItems)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSelect(date))
                    .accessibilityLabel(accessibilityDate(date))
                    .dropDestination(for: String.self) { payloads, _ in
                        guard let payload = payloads.first else { return false }
                        return onDropPayload?(payload, date) ?? false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func calendarDayLabel(
        for date: Date,
        flowItems: [HistoryCalendarItem]
    ) -> some View {
        if selectionMode == .week {
            dayContents(for: date, flowItems: flowItems)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(dayBackground(date))
                .clipShape(dayShape(date))
                .contentShape(Rectangle())
        } else {
            ZStack {
                Color.clear

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption)
                        .frame(width: 24, height: 20)
                        .foregroundStyle(dayForeground(date))
                        .background(dayBackground(date))
                        .clipShape(Capsule())

                    calendarIndicators(for: date, flowItems: flowItems)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .contentShape(Rectangle())
        }
    }

    private func dayContents(
        for date: Date,
        flowItems: [HistoryCalendarItem]
    ) -> some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption)
                .frame(height: 20)
                .foregroundStyle(dayForeground(date))

            calendarIndicators(for: date, flowItems: flowItems)
        }
    }

    @ViewBuilder
    private func calendarIndicators(for date: Date, flowItems: [HistoryCalendarItem]) -> some View {
        switch indicatorSource {
        case .flowHistory:
            HistoryCalendarFlowIndicators(items: flowItems, date: date, maximumVisibleCount: 3)
        case .filteredFlowHistory(let visibleTypes):
            HistoryCalendarFlowIndicators(
                items: HistoryCalendarIndicatorFilter().items(
                    from: flowItems,
                    visibleAreaTypes: visibleTypes
                ),
                date: date,
                maximumVisibleCount: 3
            )
        case .statistics(let indicators):
            HStack(spacing: 3) {
                ForEach(indicators.filter { calendar.isDate($0.date, inSameDayAs: date) }.prefix(3)) { indicator in
                    Circle()
                        .fill(Color(hex: indicator.colorHex))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        case .tasks(let filter):
            CalendarTaskIndicators(
                todos: (taskSnapshot?.todos(on: date) ?? []).filter(filter.includes),
                date: date,
                maximumVisibleCount: 3
            )
        }
    }

    private var weekdaySymbols: [String] {
        CalendarWeekdaySymbols.orderedAbbreviated(calendar: calendar)
    }

    private func dayForeground(_ date: Date) -> Color {
        guard calendar.isDate(date, equalTo: selectedDate, toGranularity: .month) else { return .secondary }
        if selectionMode == .week, isInSelectedWeek(date) { return .primary }
        return calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary
    }

    @ViewBuilder
    private func dayBackground(_ date: Date) -> some View {
        if selectionMode == .week, isInSelectedWeek(date) {
            Color.accentColor.opacity(0.22)
        } else if calendar.isDate(date, inSameDayAs: selectedDate) {
            Color.accentColor
        } else if calendar.isDateInToday(date) {
            Color.accentColor.opacity(0.16)
        } else {
            Color.clear
        }
    }

    private func accessibilityDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).year().month().day().weekday())
    }

    private func canSelect(_ date: Date) -> Bool {
        guard let maximumDate else { return true }
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: maximumDate)
    }

    private func isInSelectedWeek(_ date: Date) -> Bool {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return false }
        let offset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: interval.start),
            to: calendar.startOfDay(for: date)
        ).day
        return offset.map { (0..<7).contains($0) } ?? false
    }

    private func dayShape(_ date: Date) -> UnevenRoundedRectangle {
        guard selectionMode == .week, isInSelectedWeek(date),
              let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return UnevenRoundedRectangle(cornerRadii: .init(topLeading: 12, bottomLeading: 12, bottomTrailing: 12, topTrailing: 12))
        }

        let isStart = calendar.isDate(date, inSameDayAs: interval.start)
        let lastDate = calendar.date(byAdding: .day, value: 6, to: interval.start) ?? interval.start
        let isEnd = calendar.isDate(date, inSameDayAs: lastDate)
        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: isStart ? 6 : 0,
                bottomLeading: isStart ? 6 : 0,
                bottomTrailing: isEnd ? 6 : 0,
                topTrailing: isEnd ? 6 : 0
            )
        )
    }
}

enum HistoryMiniCalendarSelectionMode {
    case day
    case week
}
#endif

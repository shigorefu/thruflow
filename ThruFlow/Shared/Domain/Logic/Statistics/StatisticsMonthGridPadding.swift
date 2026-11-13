import Foundation

struct StatisticsMonthGridPadding: Equatable, Sendable {
    let leadingPlaceholderCount: Int
    let trailingPlaceholderCount: Int

    nonisolated init(dates: [Date], calendar: Calendar) {
        guard let firstDate = dates.first else {
            leadingPlaceholderCount = 0
            trailingPlaceholderCount = 0
            return
        }

        let weekday = calendar.component(.weekday, from: firstDate)
        leadingPlaceholderCount = (weekday - calendar.firstWeekday + 7) % 7
        trailingPlaceholderCount = (
            7 - ((leadingPlaceholderCount + dates.count) % 7)
        ) % 7
    }

    nonisolated func padding<Element>(_ elements: [Element]) -> [Element?] {
        Array(repeating: nil, count: leadingPlaceholderCount) +
            elements.map(Optional.some) +
            Array(repeating: nil, count: trailingPlaceholderCount)
    }
}

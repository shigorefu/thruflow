import Foundation
import Testing
@testable import ThruFlow

@MainActor struct StatisticsTrendSmoothingTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func monthIncludesLeapAndOrdinaryCalendarDaysWithoutInventedComparison() {
        for (year, month, count) in [(2024, 2, 29), (2026, 2, 28), (2026, 4, 30), (2026, 3, 31)] {
            let snapshot = StatisticsPeriodBuilder(calendar: calendar).build(flowRecords: [], achievementRecords: [],
                filter: StatisticsPeriodFilter(period: .month, anchorDate: date(year, month, 10)))
            #expect(snapshot.trend.count == count)
            #expect(snapshot.trend.last?.date == date(year, month, count))
            #expect(snapshot.trendPeriod == .month)
            if month == 3 {
                #expect(snapshot.trend[27].hasComparison)
                #expect(snapshot.trend[28...].allSatisfy { !$0.hasComparison })
            }
        }
    }

    @Test func trailingMeansIncludeZerosExcludeFutureAndDropOldestDay() {
        let points = (0..<10).map { index in
            StatisticsTrendPoint(index: index, date: date(2026, 9, index + 1), comparisonDate: date(2026, 8, index + 1),
                focusSeconds: index == 0 ? 420 : (index == 7 ? 840 : 0), previousFocusSeconds: 0,
                completedTaskCount: index == 0 ? 7 : 0, previousCompletedTaskCount: 0)
        }
        let values = StatisticsTrendSmoothing.build(points: points, period: .month, today: date(2026, 9, 8))
        #expect(values.count == 8)
        #expect(values[0].focusMinutes == 7)
        #expect(values[1].focusMinutes == 3.5)
        #expect(values[6].focusMinutes == 1)
        #expect(values[7].focusMinutes == 2)
        #expect(values[7].completedTasks == 0)
        #expect(StatisticsTrendSmoothing.build(points: points, period: .week, today: date(2026, 8, 31)).isEmpty)
    }

    @Test func yearUsesThreeMonthsAndCustomRangeExposesItsRealGranularity() {
        let points = (0..<4).map { index in
            StatisticsTrendPoint(index: index, date: date(2026, index + 1, 1), comparisonDate: date(2025, index + 1, 1),
                focusSeconds: (index + 1) * 60, previousFocusSeconds: 0, completedTaskCount: index + 1, previousCompletedTaskCount: 0)
        }
        let values = StatisticsTrendSmoothing.build(points: points, period: .year, today: date(2026, 4, 15))
        #expect(values.map(\.focusMinutes) == [1, 1.5, 2, 3])
        let snapshot = StatisticsPeriodBuilder(calendar: calendar).build(flowRecords: [], achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .year, customStartDate: date(2026, 1, 1), customEndDate: date(2026, 3, 31)))
        #expect(snapshot.trend.count == 90)
        #expect(snapshot.trendPeriod == .month)
    }
}

import Foundation
import Testing
@testable import ThruFlow

@MainActor
struct StatisticsGroupedTrendTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.firstWeekday = 2
        return value
    }

    @Test func groupsKeepStableIdentityFallbacksAndAllFocusBeyondTheDistributionLimit() throws {
        var records = (1...8).map { index in
            record(date: date(2026, 9, 5), seconds: index * 60, areaID: UUID(), projectID: UUID())
        }
        records.append(record(date: date(2026, 9, 5), seconds: 30, areaID: nil, projectID: nil))
        records.append(record(date: date(2026, 9, 5), seconds: -60, areaID: UUID(), projectID: UUID()))
        records.append(record(date: date(2026, 9, 5), seconds: 0, areaID: UUID(), projectID: UUID()))
        let builder = StatisticsPeriodBuilder(calendar: calendar)
        let filter = StatisticsPeriodFilter(period: .month, anchorDate: date(2026, 9, 8))
        let snapshot = builder.build(flowRecords: records, achievementRecords: [], filter: filter)
        let reversed = builder.build(flowRecords: Array(records.reversed()), achievementRecords: [], filter: filter)

        #expect(snapshot.areaDistribution.count == 6)
        #expect(snapshot.projectDistribution.count == 6)
        #expect(snapshot.areaTrendSeries.count == 9)
        #expect(snapshot.projectTrendSeries.count == 9)
        #expect(snapshot.areaTrendSeries.map(\.id) == reversed.areaTrendSeries.map(\.id))
        #expect(snapshot.projectTrendSeries.map(\.id) == reversed.projectTrendSeries.map(\.id))
        #expect(snapshot.areaTrendSeries.contains { $0.id == "area:other" })
        #expect(snapshot.projectTrendSeries.contains { $0.id == "project:unassigned" })
        #expect(snapshot.projectTrendSeries.filter { $0.name == "Same name" }.count == 8)
        for series in snapshot.areaTrendSeries + snapshot.projectTrendSeries {
            #expect(series.id != "distribution:other")
            #expect(series.points.count == 30)
            #expect(series.points.filter { $0.focusSeconds > 0 }.count == 1)
            #expect(series.points.reduce(0) { $0 + $1.focusSeconds } == series.totalFocusSeconds)
        }
        let projectTotals = snapshot.projectTrendSeries.reduce(0) { $0 + $1.totalFocusSeconds }
        let areaTotals = snapshot.areaTrendSeries.reduce(0) { $0 + $1.totalFocusSeconds }
        #expect(projectTotals == 2_190)
        #expect(projectTotals == snapshot.projectDistribution.reduce(0) { $0 + $1.focusSeconds })
        #expect(areaTotals == snapshot.areaDistribution.reduce(0) { $0 + $1.focusSeconds })
        #expect(projectTotals == snapshot.summary.totalFocusSeconds)
        let firstID = try #require(records.first?.areaID)
        let first = try #require(snapshot.areaTrendSeries.first { $0.id == "area:\(firstID)" })
        #expect(first.symbol == "📚")
        #expect(first.colorHex == "#00AA66")
    }

    @Test func groupedFocusHonorsLogicalDaysAreaAndSearchWithoutChangingCompletedTaskCounts() throws {
        let areaID = UUID()
        let projectID = UUID()
        let sessionID = UUID()
        let records = [
            record(date: date(2026, 9, 2, 1), seconds: 120, areaID: areaID, projectID: projectID, sessionID: sessionID),
            record(date: date(2026, 9, 2, 4), seconds: 180, areaID: areaID, projectID: projectID, sessionID: sessionID),
            record(date: date(2026, 9, 2, 4), seconds: 240, areaID: UUID(), projectID: projectID),
            record(date: date(2026, 9, 2, 4), seconds: 300, areaID: areaID, projectID: projectID, task: "Excluded"),
            record(date: date(2026, 8, 31, 4), seconds: 360, areaID: areaID, projectID: projectID)
        ]
        let achievements = [date(2026, 9, 1, 5), date(2026, 9, 2, 5)].map {
            StatisticsPeriodAchievementRecord(
                completedAt: $0, todoID: UUID(), todoTitle: "Keep", todoHashtags: [], todoNotes: "",
                areaID: areaID, areaName: "Same name", areaSymbol: "📚", areaColorHex: "#00AA66"
            )
        }
        let builder = StatisticsPeriodBuilder(calendar: calendar, dayBoundary: AppDayBoundary(hour: 3))
        let filter = StatisticsPeriodFilter(
            period: .month, anchorDate: date(2026, 9, 1),
            customStartDate: date(2026, 9, 1), customEndDate: date(2026, 9, 2),
            areaIDs: [areaID], query: "Keep"
        )
        let snapshot = builder.build(flowRecords: records, achievementRecords: achievements, filter: filter)
        let withoutFlows = builder.build(flowRecords: [], achievementRecords: achievements, filter: filter)
        let area = try #require(snapshot.areaTrendSeries.first)
        let project = try #require(snapshot.projectTrendSeries.first)
        #expect(area.points.map(\.focusSeconds) == [120, 180])
        #expect(project.points == area.points)
        #expect(snapshot.summary.flowCount == 1)
        #expect(snapshot.summary.totalFocusSeconds == 300)
        #expect(snapshot.trend.map(\.completedTaskCount) == [1, 1])
        #expect(snapshot.trend.map(\.completedTaskCount) == withoutFlows.trend.map(\.completedTaskCount))
        #expect(snapshot.trend.map(\.previousCompletedTaskCount) == withoutFlows.trend.map(\.previousCompletedTaskCount))
        #expect(snapshot.trend.map(\.skipsTaskDay) == withoutFlows.trend.map(\.skipsTaskDay))
        #expect(snapshot.trend.map(\.skipsPreviousTaskDay) == withoutFlows.trend.map(\.skipsPreviousTaskDay))
    }

    @Test func groupedBucketsMatchAggregateForWeekMonthYearAndShortOrLongCustomRanges() {
        let areaID = UUID()
        let projectID = UUID()
        let records = [
            record(date: date(2026, 1, 31), seconds: 60, areaID: areaID, projectID: projectID),
            record(date: date(2026, 2, 1), seconds: 120, areaID: areaID, projectID: projectID),
            record(date: date(2026, 5, 15), seconds: 180, areaID: areaID, projectID: projectID),
            record(date: date(2026, 9, 7), seconds: 240, areaID: areaID, projectID: projectID)
        ]
        let filters = [
            StatisticsPeriodFilter(period: .week, anchorDate: date(2026, 9, 7)),
            StatisticsPeriodFilter(period: .month, anchorDate: date(2026, 9, 7)),
            StatisticsPeriodFilter(period: .year, anchorDate: date(2026, 9, 7)),
            StatisticsPeriodFilter(period: .month, anchorDate: date(2026, 1, 31),
                                   customStartDate: date(2026, 1, 31), customEndDate: date(2026, 2, 1)),
            StatisticsPeriodFilter(period: .month, anchorDate: date(2026, 1, 15),
                                   customStartDate: date(2026, 1, 15), customEndDate: date(2026, 5, 15))
        ]
        for filter in filters {
            let snapshot = StatisticsPeriodBuilder(calendar: calendar).build(
                flowRecords: records, achievementRecords: [], filter: filter
            )
            for series in snapshot.areaTrendSeries + snapshot.projectTrendSeries {
                #expect(series.points.map(\.date) == snapshot.trend.map(\.date))
                #expect(series.points.map(\.index) == snapshot.trend.map(\.index))
                #expect(series.totalFocusSeconds == snapshot.summary.totalFocusSeconds)
                #expect(series.points.reduce(0) { $0 + $1.focusSeconds } == series.totalFocusSeconds)
            }
            for point in snapshot.trend {
                #expect(snapshot.areaTrendSeries.reduce(0) { $0 + $1.points[point.index].focusSeconds } == point.focusSeconds)
                #expect(snapshot.projectTrendSeries.reduce(0) { $0 + $1.points[point.index].focusSeconds } == point.focusSeconds)
            }
        }
        let year = StatisticsPeriodBuilder(calendar: calendar).build(
            flowRecords: records, achievementRecords: [], filter: filters[2]
        )
        #expect(year.trend.count == 12)
        #expect(year.areaTrendSeries.first?.points[0].focusSeconds == 60)
        #expect(year.areaTrendSeries.first?.points[1].focusSeconds == 120)
        let custom = StatisticsPeriodBuilder(calendar: calendar).build(
            flowRecords: records, achievementRecords: [], filter: filters[4]
        )
        #expect(custom.trendPeriod == .year)
    }

    private func record(
        date: Date, seconds: Int, areaID: UUID?, projectID: UUID?, sessionID: UUID = UUID(), task: String = "Keep"
    ) -> StatisticsPeriodFlowRecord {
        StatisticsPeriodFlowRecord(
            sessionID: sessionID, startedAt: date, focusSeconds: seconds, areaID: areaID,
            areaName: areaID == nil ? "" : "Same name", areaSymbol: "📚", areaColorHex: "#00AA66",
            todoID: UUID(), todoTitle: task, todoHashtags: [], todoNotes: "", intent: "", result: "",
            projectID: projectID, projectName: projectID == nil ? "" : "Same name"
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct HabitCompletionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func day(_ number: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: number, hour: hour))!
    }

    private func summary(_ todos: [Todo], filter: StatisticsPeriodFilter? = nil,
                         now: Date? = nil, boundary: AppDayBoundary = .midnight) -> HabitCompletionSummary {
        StatisticsPeriodBuilder(calendar: calendar, dayBoundary: boundary).build(
            flowRecords: [], achievementRecords: [],
            filter: filter ?? StatisticsPeriodFilter(period: .month, anchorDate: day(8)),
            habitRecords: todos.compactMap { HabitCompletionRecord(todo: $0, calendar: calendar, dayBoundary: boundary) },
            now: now ?? day(9, hour: 12)
        ).habitCompletion
    }

    @Test func partialRatesUseEqualOccurrenceWeightAndClampAtOne() throws {
        let area = Area(name: "Exercise", type: .habit)
        let other = Area(name: "Read", type: .habit)
        let half = Todo(title: "", area: area, measurement: .minutes, plannedAmount: 40,
                        focusDurationSeconds: 20 * 60, scheduledDate: day(7))
        let zero = Todo(title: "", area: area, scheduledDate: day(8))
        let excess = Todo(title: "", area: other, measurement: .minutes, plannedAmount: 10,
                          focusDurationSeconds: 30 * 60, scheduledDate: day(8))
        let result = summary([half, zero, excess])
        #expect(result.occurrenceCount == 3)
        #expect(result.completedFraction == 1.5)
        #expect(result.rate == 0.5)
        #expect(result.areas.first { $0.id == "area:\(area.id)" }?.rate == 0.25)
        #expect(result.areas.first { $0.id == "area:\(other.id)" }?.rate == 1)
    }

    @Test func blockFractionUsesExactTimeAndLegacyProgressOnlyWhenSecondsAbsent() throws {
        let area = Area(name: "Study", type: .habit)
        let partial = Todo(title: "", area: area, measurement: .focusBlocks, plannedAmount: 1,
                           focusDurationSeconds: 12 * 60, scheduledDate: day(7))
        let legacy = Todo(title: "", area: area, measurement: .focusBlocks, plannedAmount: 2,
                          actualProgress: 1, scheduledDate: day(8))
        let explicitZero = Todo(title: "", area: area, measurement: .minutes, plannedAmount: 40,
                                actualProgress: 20, focusDurationSeconds: 0, scheduledDate: day(9))
        #expect(try #require(HabitCompletionRecord(todo: partial, calendar: calendar)).fraction == 0.48)
        #expect(try #require(HabitCompletionRecord(todo: legacy, calendar: calendar)).fraction == 0.5)
        #expect(try #require(HabitCompletionRecord(todo: explicitZero, calendar: calendar)).fraction == 0)
        partial.setCompleted(true, now: day(7, hour: 12))
        #expect(try #require(HabitCompletionRecord(todo: partial, calendar: calendar)).fraction == 1)
    }

    @Test func syncDuplicatesAreOneObligationAndFiltersKeepPartialProgress() {
        let area = Area(name: "Exercise", type: .habit)
        let other = Area(name: "Exercise", type: .habit)
        let partial = Todo(title: "Squat", area: area, measurement: .minutes, plannedAmount: 40,
                           focusDurationSeconds: 20 * 60, scheduledDate: day(8))
        let duplicate = Todo(title: "Squat", area: area, scheduledDate: day(8))
        let unrelated = Todo(title: "Walk", area: other, scheduledDate: day(8))
        let records = [partial, duplicate, unrelated]
        #expect(summary(records).occurrenceCount == 2)
        #expect(summary(records).rate == 0.25)
        #expect(summary(records) == summary(records.reversed()))
        let filtered = summary(records, filter: StatisticsPeriodFilter(
            period: .month, anchorDate: day(8), areaIDs: [area.id], query: "sQuAt"))
        #expect(filtered.occurrenceCount == 1)
        #expect(filtered.rate == 0.5)
    }

    @Test func onlyDueSavedHabitOccurrencesCountWithLogicalDayBoundary() {
        let area = Area(name: "Exercise", type: .habit)
        let previous = Todo(title: "", area: area, scheduledDate: day(7))
        let current = Todo(title: "", area: area, scheduledDate: day(8))
        let future = Todo(title: "", area: area, scheduledDate: day(9))
        let manual = Todo(title: "Exam", area: area, habitOccurrence: false, scheduledDate: day(8))
        let deleted = Todo(title: "", area: area, scheduledDate: day(8))
        deleted.deletedAt = day(8)
        let connector = Todo(title: "Imported", area: area, scheduledDate: day(8))
        connector.externalTaskLinkRawValue = "imported"
        let filter = StatisticsPeriodFilter(period: .month, anchorDate: day(8),
                                            customStartDate: day(8), customEndDate: day(9))
        let todos = [previous, current, future, manual, deleted, connector]
        let result = summary(todos, filter: filter, now: day(9, hour: 1), boundary: AppDayBoundary(hour: 2))
        #expect(result.occurrenceCount == 0)
        #expect(result.rate == nil)
        let afterBoundary = summary(todos, filter: filter, now: day(9, hour: 2), boundary: AppDayBoundary(hour: 2))
        #expect(afterBoundary.occurrenceCount == 1)
        #expect(afterBoundary.rate == 0)
        let empty = summary([future, manual, deleted, connector], filter: filter,
                            now: day(9, hour: 1), boundary: AppDayBoundary(hour: 2))
        #expect(empty.rate == nil)
        #expect(empty.areas.isEmpty)
    }

    @Test func todayCountsOnlyFullGoalsUntilConfiguredDayBoundary() {
        let area = Area(name: "Exercise", type: .habit)
        let complete = Todo(title: "", area: area, scheduledDate: day(8))
        complete.setCompleted(true, now: day(8, hour: 3))
        let partial = Todo(title: "", area: Area(name: "Study", type: .habit),
                           measurement: .minutes, plannedAmount: 20,
                           focusDurationSeconds: 600, scheduledDate: day(8))
        let zero = Todo(title: "", area: Area(name: "Read", type: .habit), scheduledDate: day(8))
        let boundary = AppDayBoundary(hour: 2)

        let open = summary([complete, partial, zero], now: day(9, hour: 1), boundary: boundary)
        #expect(open.occurrenceCount == 1)
        #expect(open.rate == 1)
        #expect(open.areas.map(\.id) == ["area:\(area.id)"])

        let closed = summary([complete, partial, zero], now: day(9, hour: 2), boundary: boundary)
        #expect(closed.occurrenceCount == 3)
        #expect(closed.rate == 0.5)
        #expect(closed.areas.first { $0.name == "Study" }?.rate == 0.5)
    }

    @Test func pausedOrArchivedUnstartedOccurrencesAreExcludedButHistoryRemains() {
        let area = Area(name: "Exercise", type: .habit)
        area.habitPausePeriods = [HabitPausePeriod(startsOn: day(7), endsBefore: day(10))]
        let unstarted = Todo(title: "", area: area, scheduledDate: day(7))
        let partial = Todo(title: "", area: area, measurement: .minutes, plannedAmount: 40,
                           focusDurationSeconds: 20 * 60, scheduledDate: day(8))
        let completed = Todo(title: "", area: area, scheduledDate: day(9))
        completed.setCompleted(true, now: day(9))
        #expect(summary([unstarted, partial, completed]).rate == 0.75)
        area.archivedAt = day(9)
        partial.archivedAt = day(9)
        #expect(summary([unstarted, partial, completed]).occurrenceCount == 2)
        #expect(summary([unstarted, partial, completed]).rate == 0.75)
    }

    @Test func archivingAreaDoesNotErasePriorUnfinishedObligations() {
        let area = Area(name: "Exercise", type: .habit)
        let past = Todo(title: "", area: area, scheduledDate: day(7))
        let archiveDay = Todo(title: "", area: area, scheduledDate: day(8))
        let partial = Todo(title: "", area: area, measurement: .minutes, plannedAmount: 40,
                           focusDurationSeconds: 20 * 60, scheduledDate: day(9))
        // At 01:00 with a 02:00 boundary, the archive belongs to September 8.
        area.archivedAt = day(9, hour: 1)
        let result = summary([past, archiveDay, partial], now: day(10, hour: 2), boundary: AppDayBoundary(hour: 2))
        #expect(result.occurrenceCount == 2)
        #expect(result.rate == 0.25)
    }

    @Test func actorFetchesIncompleteOccurrencesAtLogicalMidnight() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Area.self, Todo.self, FlowSession.self,
                                           FlowSegment.self, FlowBreak.self, configurations: config)
        let context = ModelContext(container)
        let area = Area(name: "Exercise", type: .habit)
        let partial = Todo(title: "", area: area, measurement: .minutes, plannedAmount: 40,
                           focusDurationSeconds: 20 * 60, scheduledDate: day(8))
        context.insert(area)
        context.insert(partial)
        try context.save()
        let snapshot = try await StatisticsProjectionActor(modelContainer: container).load(
            filter: StatisticsPeriodFilter(period: .month, anchorDate: day(8),
                                            customStartDate: day(8), customEndDate: day(8)),
            calendar: calendar, dayBoundary: AppDayBoundary(hour: 2))
        #expect(snapshot.habitCompletion.rate == 0.5)
        #expect(snapshot.habitCompletion.occurrenceCount == 1)
        #expect(snapshot.summary.completedTaskCount == 0)
    }

    @Test(arguments: [GoalScheduleKind.everyDay, .weeklyCount, .weekdays],
          [TodoMeasurement.minutes, .focusBlocks])
    func nextDayStartsFreshAndPreservesYesterdayHistory(schedule: GoalScheduleKind,
                                                       measurement: TodoMeasurement) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Area.self, Todo.self, FlowSession.self,
                                           FlowSegment.self, FlowBreak.self, configurations: config)
        let context = ModelContext(container)
        let area = Area(name: "Exercise", type: .habit, goalTarget: measurement == .minutes ? 40 : 1,
                        goalPeriod: .weekly, goalUnit: measurement == .minutes ? .minutes : .focusBlocks,
                        goalSchedule: schedule, weeklyTargetCount: 3, weekdayMask: 127)
        let old = Todo(title: "Exercise", area: area, habitOccurrence: true,
                       measurement: measurement, plannedAmount: area.goalTarget, scheduledDate: day(7))
        let session = FlowSession(area: area, todo: old, mode: .twentyFiveFive, status: .completed,
                                  startedAt: day(7, hour: 12), plannedEndAt: day(7, hour: 13),
                                  endedAt: day(7, hour: 13), plannedFocusDurationSeconds: 1500,
                                  actualFocusDurationSeconds: 12 * 60, plannedBreakDurationSeconds: 300)
        context.insert(area)
        context.insert(old)
        context.insert(session)
        try FlowProgressReconciler().reconcile(todos: [old], areas: [area], modelContext: context)
        try context.save()
        let materializer = HabitTodoMaterializer(calendar: calendar, dayBoundary: AppDayBoundary(hour: 2))
        #expect(try materializer.materialize(areas: [area], dates: [day(8)],
                                            modelContext: context, now: day(8, hour: 3)))
        #expect(try !materializer.materialize(areas: [area], dates: [day(8)],
                                             modelContext: context, now: day(8, hour: 3)))
        let loaded = try ModelContext(container).fetch(FetchDescriptor<Todo>()).filter { !$0.isDeleted }
        let yesterday = try #require(loaded.first { $0.id == old.id })
        let today = try #require(loaded.first { $0.scheduledDate == day(8) })
        #expect(loaded.count == 2)
        #expect(yesterday.scheduledDate == day(7))
        #expect(yesterday.recordedFocusSeconds == 12 * 60)
        #expect(today.id != old.id)
        #expect(today.recordedFocusSeconds == 0)
        #expect(today.actualProgress == 0)
        #expect(!today.isCompleted)
        #expect(session.todo?.id == old.id)
        #expect(session.startedAt == day(7, hour: 12))
    }

    @Test func weeklyPlannerRespectsDayBoundaryAndCompletedQuota() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Area.self, Todo.self, FlowSession.self,
                                           FlowSegment.self, FlowBreak.self, configurations: config)
        let context = ModelContext(container)
        let area = Area(name: "Exercise", type: .habit, goalTarget: 1, goalPeriod: .weekly,
                        goalUnit: .occurrences, goalSchedule: .weeklyCount, weeklyTargetCount: 1)
        let old = Todo(title: "", area: area, scheduledDate: day(7))
        context.insert(area)
        context.insert(old)
        try context.save()
        let materializer = HabitTodoMaterializer(calendar: calendar, dayBoundary: AppDayBoundary(hour: 2))
        #expect(try !materializer.materialize(areas: [area], dates: [day(7), day(8)],
                                             modelContext: context, now: day(8, hour: 1)))
        old.setCompleted(true, now: day(7, hour: 15))
        try context.save()
        #expect(try !materializer.materialize(areas: [area], dates: [day(8)],
                                             modelContext: context, now: day(8, hour: 3)))
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 1)
    }
    private func weeklyArea(target: Int = 6) -> Area {
        Area(name: "Exercise", type: .habit, goalTarget: 1, goalPeriod: .weekly,
             goalUnit: .occurrences, goalSchedule: .weeklyCount, weeklyTargetCount: target)
    }

    private func weeklyAttempts(_ area: Area, days: ClosedRange<Int> = 7...13,
                                completed: Set<Int>) -> [Todo] {
        days.map { number in
            let todo = Todo(title: "Exercise", area: area, scheduledDate: day(number))
            if completed.contains(number) { todo.setCompleted(true, now: day(number, hour: 12)) }
            return todo
        }
    }

    @Test(arguments: [7, 13])
    func sixWeeklyCompletionsMeetQuotaRegardlessOfMissedDay(missedDay: Int) {
        let area = weeklyArea()
        let todos = weeklyAttempts(area, completed: Set(7...13).subtracting([missedDay]))
        let result = summary(todos, now: day(14))
        #expect(result.occurrenceCount == 6)
        #expect(result.completedFraction == 6)
        #expect(result.rate == 1)
        #expect(result == summary(todos.reversed(), now: day(14)))
    }

    @Test func weeklyPartialAttemptsDoNotCombineIntoExtraCompletedDays() {
        let area = weeklyArea()
        let todos = weeklyAttempts(area, completed: Set(7...11))
        for todo in todos.suffix(2) {
            todo.measurement = .minutes
            todo.plannedAmount = 40
            todo.focusDurationSeconds = 20 * 60
        }
        let result = summary(todos, now: day(14))
        #expect(result.occurrenceCount == 6)
        #expect(result.completedFraction == 5.5)
        #expect(result.rate == 5.5 / 6)
        area.weeklyTargetCount = 1
        #expect(summary(Array(todos.suffix(2)), now: day(14)).rate == 0.5)
    }

    @Test func weeklyQuotaKeepsWeeksOwnersAndFiltersSeparate() {
        let first = weeklyArea()
        let second = weeklyArea(target: 2)
        let complete = weeklyAttempts(first, completed: Set(7...12))
        let nextWeek = weeklyAttempts(first, days: 14...15, completed: [14])
        let other = weeklyAttempts(second, days: 7...8, completed: [])
        let duplicate = Todo(title: "Exercise", area: first, scheduledDate: day(7))
        let result = summary(complete + nextWeek + other + [duplicate], now: day(16))
        #expect(result.occurrenceCount == 10)
        #expect(result.completedFraction == 7)
        let filtered = summary(complete + other, filter: StatisticsPeriodFilter(
            period: .week, anchorDate: day(7), areaIDs: [first.id]), now: day(16))
        #expect(filtered.rate == 1)
        let clipped = summary(complete, filter: StatisticsPeriodFilter(
            period: .month, anchorDate: day(13), customStartDate: day(13), customEndDate: day(13)),
            now: day(16))
        #expect(clipped.rate == 0)
        #expect(clipped.occurrenceCount == 1)
    }

    @Test func weeklyQuotaRespectsWeekStartAndOpenLogicalDay() {
        let area = weeklyArea(target: 1)
        let saturday = weeklyAttempts(area, days: 12...12, completed: [12])
        let sunday = weeklyAttempts(area, days: 13...13, completed: [])
        var sundayCalendar = calendar
        sundayCalendar.firstWeekday = 1
        let result = StatisticsPeriodBuilder(calendar: sundayCalendar).build(
            flowRecords: [], achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .month, anchorDate: day(13)),
            habitRecords: (saturday + sunday).compactMap { HabitCompletionRecord(todo: $0, calendar: sundayCalendar) },
            now: day(14)).habitCompletion
        #expect(result.rate == 0.5)
        let boundary = AppDayBoundary(hour: 2)
        #expect(summary(saturday + sunday, now: day(14, hour: 1), boundary: boundary).rate == 1)
        area.weeklyTargetCount = 2
        #expect(summary(saturday + sunday, now: day(14, hour: 1), boundary: boundary).occurrenceCount == 1)
        #expect(summary(saturday + sunday, now: day(14, hour: 2), boundary: boundary).rate == 0.5)
    }

    @Test func projectWeeklyQuotaIsIndependentFromParent() throws {
        let area = weeklyArea(target: 6)
        let project = Project(name: "Report", area: area, createdAt: day(1))
        project.habitSettings = ProjectHabitSettings(
            isEnabled: true, goalSchedule: .weeklyCount, weeklyTargetCount: 1, startsOn: day(1))
        let first = Todo(title: "", area: area, project: project, habitOccurrence: true, scheduledDate: day(7))
        first.setCompleted(true, now: day(7, hour: 12))
        let missed = Todo(title: "", area: area, project: project, habitOccurrence: true, scheduledDate: day(8))
        let parent = weeklyAttempts(area, days: 7...8, completed: [])
        let result = summary([first, missed] + parent, now: day(14))
        #expect(result.occurrenceCount == 3)
        #expect(result.areas.first { $0.id == "project:\(project.id)" }?.rate == 1)
        #expect(result.areas.first { $0.id == "area:\(area.id)" }?.rate == 0)
    }

    @Test func taskTrendSkipsOnlyPostQuotaRestDays() throws {
        let area = weeklyArea()
        let todos = weeklyAttempts(area, completed: Set(7...12))
        let records = todos.compactMap { HabitCompletionRecord(todo: $0, calendar: calendar) }
        let builder = StatisticsPeriodBuilder(calendar: calendar)
        let filter = StatisticsPeriodFilter(period: .week, anchorDate: day(14))
        let snapshot = builder.build(flowRecords: [], achievementRecords: [],
            filter: filter, habitRecords: records, now: day(21))
        #expect(snapshot.trend.first { $0.comparisonDate == day(13) }?.skipsPreviousTaskDay == true)
        #expect(snapshot.trend.first?.skipsPreviousTaskDay == false)
        #expect(snapshot.trend.allSatisfy { !$0.skipsTaskDay })

        let current = StatisticsPeriodFilter(period: .week, anchorDate: day(7))
        let initial = builder.build(flowRecords: [], achievementRecords: [],
            filter: current, habitRecords: records, now: day(14))
        #expect(initial.trend.last?.skipsTaskDay == true)
        #expect(initial.trend.last?.focusSeconds == 0)
        #expect(initial.trend.count == 7)
        let ordinary = builder.build(flowRecords: [], achievementRecords: [],
            filter: current, habitRecords: records, ordinaryTaskDays: [day(13)], now: day(14))
        #expect(ordinary.trend.last?.skipsTaskDay == false)

        let daily = Todo(title: "", area: Area(name: "Read", type: .habit), scheduledDate: day(13))
        let guarded = builder.build(flowRecords: [], achievementRecords: [], filter: current,
            habitRecords: records + [try #require(HabitCompletionRecord(todo: daily, calendar: calendar))],
            now: day(14))
        #expect(guarded.trend.last?.skipsTaskDay == false)
        let yearly = builder.build(flowRecords: [], achievementRecords: [],
            filter: StatisticsPeriodFilter(period: .year, anchorDate: day(7)),
            habitRecords: records, now: day(14))
        #expect(yearly.trend.allSatisfy { !$0.skipsTaskDay && !$0.skipsPreviousTaskDay })
    }

    @Test func actorLoadsEnclosingWeekForCustomRestDayAndPendingTaskGuard() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Area.self, Todo.self, FlowSession.self,
                                           FlowSegment.self, FlowBreak.self, configurations: config)
        let context = container.mainContext
        let area = weeklyArea()
        context.insert(area)
        for todo in weeklyAttempts(area, completed: Set(7...12)) { context.insert(todo) }
        try context.save()
        let filter = StatisticsPeriodFilter(period: .month, anchorDate: day(13),
            customStartDate: day(13), customEndDate: day(13))
        let initial = try await StatisticsProjectionActor(modelContainer: container).load(
            filter: filter, calendar: calendar, dayBoundary: .midnight)
        #expect(initial.trend.count == 1)
        #expect(initial.trend.first?.skipsTaskDay == true)
        #expect(initial.habitCompletion.rate == 0)
        let ordinary = Todo(title: "Report", area: area, habitOccurrence: false, scheduledDate: day(13))
        context.insert(ordinary)
        try context.save()
        let guarded = try await StatisticsProjectionActor(modelContainer: container).load(
            filter: filter, calendar: calendar, dayBoundary: .midnight)
        #expect(guarded.trend.first?.skipsTaskDay == false)
        ordinary.setCompleted(true, now: day(12, hour: 18))
        try context.save()
        let completedEarlier = try await StatisticsProjectionActor(modelContainer: container).load(
            filter: filter, calendar: calendar, dayBoundary: .midnight)
        #expect(completedEarlier.trend.first?.skipsTaskDay == true)
    }

    @Test func lateCompletionDoesNotTurnEarlierDaysIntoRestDays() {
        let area = weeklyArea(target: 1)
        let todos = weeklyAttempts(area, days: 7...7, completed: [])
        todos[0].setCompleted(true, now: day(11, hour: 12))
        let records = todos.compactMap { HabitCompletionRecord(todo: $0, calendar: calendar) }
        let rest = WeeklyHabitRestDays(calendar: calendar).dates(records: records,
            filter: StatisticsPeriodFilter(), ordinaryTaskDays: [], today: day(14))
        #expect(!rest.contains(day(8)))
        #expect(!rest.contains(day(11)))
        #expect(rest.contains(day(12)))
        #expect(rest.contains(day(13)))
        let boundary = AppDayBoundary(hour: 2)
        todos[0].setCompleted(false, now: day(11))
        todos[0].setCompleted(true, now: day(12, hour: 1))
        let shifted = todos.compactMap { HabitCompletionRecord(todo: $0, calendar: calendar, dayBoundary: boundary) }
        let shiftedRest = WeeklyHabitRestDays(calendar: calendar).dates(records: shifted,
            filter: StatisticsPeriodFilter(), ordinaryTaskDays: [], today: day(14))
        #expect(shiftedRest == rest)
    }

    @Test func unmetOtherWeeklyQuotaAndActualCompletionsPreventTaskGaps() {
        let area = weeklyArea(target: 1)
        let completed = weeklyAttempts(area, days: 7...7, completed: [7])
        let other = weeklyArea(target: 1)
        let pending = weeklyAttempts(other, days: 8...8, completed: [])
        let records = (completed + pending).compactMap { HabitCompletionRecord(todo: $0, calendar: calendar) }
        let rest = WeeklyHabitRestDays(calendar: calendar).dates(records: records,
            filter: StatisticsPeriodFilter(), ordinaryTaskDays: [], today: day(14))
        #expect(rest.isEmpty)
        let filtered = WeeklyHabitRestDays(calendar: calendar).dates(records: records,
            filter: StatisticsPeriodFilter(areaIDs: [area.id]), ordinaryTaskDays: [], today: day(14))
        #expect(filtered.contains(day(8)))

        let achievement = StatisticsPeriodAchievementRecord(completedAt: day(8, hour: 12),
            todoID: UUID(), todoTitle: "Report", todoHashtags: [], todoNotes: "",
            areaID: area.id, areaName: area.name, areaSymbol: "", areaColorHex: nil)
        let report = StatisticsPeriodBuilder(calendar: calendar).build(
            flowRecords: [], achievementRecords: [achievement],
            filter: StatisticsPeriodFilter(period: .week, anchorDate: day(7), areaIDs: [area.id]),
            habitRecords: records, now: day(14))
        #expect(report.trend[1].completedTaskCount == 1)
        #expect(!report.trend[1].skipsTaskDay)
        #expect(report.trend[2].skipsTaskDay)
    }

}

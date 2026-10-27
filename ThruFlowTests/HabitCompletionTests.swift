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
        #expect(result.occurrenceCount == 1)
        #expect(result.rate == 0)
        let empty = summary([future, manual, deleted, connector], filter: filter,
                            now: day(9, hour: 1), boundary: AppDayBoundary(hour: 2))
        #expect(empty.rate == nil)
        #expect(empty.areas.isEmpty)
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
        let result = summary([past, archiveDay, partial], boundary: AppDayBoundary(hour: 2))
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
}

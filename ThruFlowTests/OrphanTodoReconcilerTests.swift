import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct OrphanTodoReconcilerTests {
    @Test func reconnectsGeneratedHabitOccurrenceFromItsUniqueTemplate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let day = Date(timeIntervalSince1970: 4 * 86_400)
        let habit = dailyOccurrenceHabit(name: "Anki")
        let orphan = Todo(
            title: "",
            area: habit,
            priority: .high,
            scheduledDate: day
        )
        orphan.area = nil
        context.insert(habit)
        context.insert(orphan)
        try context.save()

        let result = try OrphanTodoReconciler(calendar: testCalendar()).reconcile(
            modelContext: context,
            now: day.addingTimeInterval(3_600)
        )

        #expect(result.reconnectedFromHistoryCount == 0)
        #expect(result.reconnectedFromHabitTemplateCount == 1)
        #expect(orphan.area?.id == habit.id)
        #expect(
            TaskBacklogBuilder(calendar: testCalendar())
                .build(todos: [orphan], now: day.addingTimeInterval(86_400))
                .overdue
                .isEmpty
        )
    }

    @Test func reconnectsOrphanWithUserDataFromFlowHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let day = Date(timeIntervalSince1970: 5 * 86_400)
        let area = Area(name: "仕事", type: .neutral)
        let orphan = Todo(title: "設計", area: area, scheduledDate: day)
        let session = FlowSession(
            area: area,
            todo: orphan,
            mode: .sprint,
            startedAt: day,
            plannedEndAt: day.addingTimeInterval(720),
            plannedFocusDurationSeconds: 720,
            plannedBreakDurationSeconds: 180
        )
        orphan.area = nil
        context.insert(area)
        context.insert(orphan)
        context.insert(session)
        try context.save()

        let result = try OrphanTodoReconciler(calendar: testCalendar()).reconcile(
            modelContext: context,
            now: day.addingTimeInterval(3_600)
        )

        #expect(result.reconnectedFromHistoryCount == 1)
        #expect(result.reconnectedFromHabitTemplateCount == 0)
        #expect(orphan.area?.id == area.id)
    }

    @Test func ambiguousOrphanIsNotGuessedAndDoesNotAppearAsOther() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let day = Date(timeIntervalSince1970: 6 * 86_400)
        let firstHabit = dailyOccurrenceHabit(name: "Anki")
        let secondHabit = dailyOccurrenceHabit(name: "運動")
        let orphan = Todo(
            title: "",
            area: firstHabit,
            priority: .high,
            scheduledDate: day
        )
        orphan.area = nil
        context.insert(firstHabit)
        context.insert(secondHabit)
        context.insert(orphan)
        try context.save()

        let result = try OrphanTodoReconciler(calendar: testCalendar()).reconcile(
            modelContext: context,
            now: day.addingTimeInterval(3_600)
        )

        #expect(!result.changed)
        #expect(orphan.area == nil)
        #expect(!TodayTodoFilter(calendar: testCalendar()).includes(orphan, on: day))
        #expect(!TaskCalendarFilter.all.includes(orphan))
        #expect(
            TaskBacklogBuilder(calendar: testCalendar())
                .build(todos: [orphan], now: day.addingTimeInterval(86_400))
                .overdue
                .isEmpty
        )
    }

    private func dailyOccurrenceHabit(name: String) -> Area {
        Area(
            name: name,
            type: .habit,
            goalTarget: 1,
            goalPeriod: .daily,
            goalUnit: .occurrences,
            goalSchedule: .everyDay
        )
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Area.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

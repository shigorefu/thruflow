import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct ArchivedHabitTodoTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 14))!
    }
    private func container() throws -> ModelContainer {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        return try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
    }
    private func habit() -> Area {
        Area(name: "AWS", type: .habit, goalTarget: 25, goalPeriod: .daily,
             goalUnit: .minutes, goalSchedule: .everyDay)
    }

    @Test func archivingRemovesPreplannedDaysAndPreventsFurtherGeneration() throws {
        let container = try container()
        let context = container.mainContext
        let area = habit()
        context.insert(area)
        let days = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: today)! }
        let materializer = HabitTodoMaterializer(calendar: calendar)
        try materializer.materialize(areas: [area], dates: days, modelContext: context, now: today)
        let todos = try context.fetch(FetchDescriptor<Todo>())
        #expect(todos.count == 7)
        area.archive(now: today.addingTimeInterval(3600), calendar: calendar)
        try context.save()
        #expect(todos.allSatisfy { $0.isDeleted })
        #expect(!RequiredTodoPlanner(calendar: calendar).shouldCreateRequiredTodo(for: area, in: todos, on: days[1]))
        #expect(try !materializer.materialize(areas: [area], dates: days,
                                             modelContext: context, now: days[1]))
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 7)
        #expect(area.isArchived)
    }

    @Test func archivePreservesHistoryProgressAndManualTasks() throws {
        let container = try container()
        let context = container.mainContext
        let area = habit()
        context.insert(area)
        let past = Todo(title: "Past", area: area, habitOccurrence: true,
                        scheduledDate: today.addingTimeInterval(-86400))
        let completed = Todo(title: "Done", area: area, habitOccurrence: true,
                             status: .completed, completedAt: today, scheduledDate: today)
        let progress = Todo(title: "Progress", area: area, habitOccurrence: true,
                            measurement: .minutes, plannedAmount: 25, actualProgress: 1,
                            focusDurationSeconds: 60, scheduledDate: today)
        let running = Todo(title: "Running", area: area, habitOccurrence: true, scheduledDate: today)
        let manual = Todo(title: "Manual", area: area, habitOccurrence: false, scheduledDate: today)
        let unused = Todo(title: "", area: area, habitOccurrence: true, scheduledDate: today)
        let kept = [past, completed, progress, running, manual]
        for todo in kept + [unused] { context.insert(todo) }
        let session = FlowSession(area: area, todo: running, mode: .twentyFiveFive,
                                  startedAt: today, plannedEndAt: today.addingTimeInterval(1500),
                                  plannedFocusDurationSeconds: 1500, plannedBreakDurationSeconds: 300)
        context.insert(session)
        try context.save()
        area.archive(now: today, calendar: calendar)
        try context.save()
        #expect(unused.isDeleted)
        #expect(kept.allSatisfy { !$0.isDeleted })
        #expect(session.todo?.id == running.id)
    }

    @Test func repairUsesArchiveDayEvenWhenAreaIsAbsentFromActiveList() throws {
        let container = try container()
        let context = container.mainContext
        let area = habit()
        area.archivedAt = today
        context.insert(area)
        // Simulate previously generated records arriving after Area archival.
        let todo = Todo(title: "", area: area, habitOccurrence: true, scheduledDate: today)
        context.insert(todo)
        try context.save()
        let materializer = HabitTodoMaterializer(calendar: calendar)
        let nextDay = today.addingTimeInterval(86400)
        #expect(try materializer.materialize(areas: [], dates: [], modelContext: context,
                                            now: nextDay, knownTodos: [todo], reconcilesDuplicates: false))
        #expect(todo.isDeleted)
        let deletedAt = todo.deletedAt
        #expect(try !materializer.materialize(areas: [], dates: [], modelContext: context,
                                             now: nextDay.addingTimeInterval(60), knownTodos: [todo]))
        #expect(todo.deletedAt == deletedAt)
    }

    @Test func archiveHonorsCustomDayBoundary() throws {
        let container = try container()
        let context = container.mainContext
        let area = habit()
        context.insert(area)
        let previousDay = today.addingTimeInterval(-86400)
        let todo = Todo(title: "", area: area, habitOccurrence: true, scheduledDate: previousDay)
        context.insert(todo)
        try context.save()
        area.archive(now: today.addingTimeInterval(2 * 3600), calendar: calendar,
                     dayBoundary: AppDayBoundary(hour: 4))
        #expect(todo.isDeleted)
    }
}

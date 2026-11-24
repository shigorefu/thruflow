import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct AreaLifecycleTests {
    @Test func restoreKeepsIdentityHistoryAndTasks() throws {
        let container = try makeContainer(); let context = container.mainContext
        let area = Area(name: "Cloud", type: .neutral); context.insert(area)
        let task = Todo(title: "Exam", area: area, habitOccurrence: false)
        context.insert(task)
        let flow = try FlowHistoryEditor().createManual(todo: task, area: area, mode: .twentyFiveFive,
            startedAt: monday, focusSeconds: 1500, modelContext: context)
        let service = AreaLifecycleService(calendar: calendar)
        try service.archive(area, modelContext: context, now: monday)
        #expect(area.isArchived)
        try service.restore(area, modelContext: context, now: wednesday)
        #expect(!area.isArchived)
        #expect(!task.isDeleted)
        #expect(flow.area?.id == area.id); #expect(flow.todo?.id == task.id)
        #expect(flow.actualFocusDurationSeconds == 1500)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Area>()).first)
        #expect(loaded.id == area.id); #expect(!loaded.isArchived)
        #expect(loaded.habitPausePeriods.isEmpty)
    }

    @Test func restoredHabitSkipsArchiveDaysAndResumesWithoutResurrectingTombstones() throws {
        let container = try makeContainer(); let context = container.mainContext
        let area = habit(); context.insert(area)
        let before = Todo(title: "", area: area, habitOccurrence: true, scheduledDate: monday)
        context.insert(before); try context.save()
        let service = AreaLifecycleService(calendar: calendar)
        try service.archive(area, modelContext: context, now: monday)
        #expect(before.isDeleted)
        try service.restore(area, modelContext: context, now: wednesday)
        let dates = [monday, monday.addingTimeInterval(86400), wednesday]
        for _ in 0..<2 {
            try HabitTodoMaterializer(calendar: calendar).materialize(areas: [area], dates: dates, modelContext: context, now: wednesday)
        }
        let active = try context.fetch(FetchDescriptor<Todo>()).filter { !$0.isDeleted }
        #expect(before.isDeleted)
        #expect(active.count == 1)
        #expect(active.first?.scheduledDate == wednesday)
        #expect(active.first?.id != before.id)
        let pauses = area.habitPausePeriods
        try service.restore(area, modelContext: context, now: wednesday.addingTimeInterval(3600))
        #expect(area.habitPausePeriods == pauses)
    }

    @Test func sameDayRestoreAllowsOneNewOccurrence() throws {
        let container = try makeContainer(); let context = container.mainContext
        let area = habit(); context.insert(area)
        let materializer = HabitTodoMaterializer(calendar: calendar)
        try materializer.materialize(areas: [area], dates: [monday], modelContext: context, now: monday)
        let original = try #require(try context.fetch(FetchDescriptor<Todo>()).first)
        let service = AreaLifecycleService(calendar: calendar)
        try service.archive(area, modelContext: context, now: monday.addingTimeInterval(3600))
        try service.restore(area, modelContext: context, now: monday.addingTimeInterval(7200))
        for _ in 0..<2 { try materializer.materialize(areas: [area], dates: [monday], modelContext: context, now: monday.addingTimeInterval(7200)) }
        #expect(area.habitPausePeriods.isEmpty)
        #expect(original.isDeleted)
        #expect(try context.fetch(FetchDescriptor<Todo>()).filter { !$0.isDeleted }.count == 1)
    }

    @Test func restorePreservesManualPauseAndRespectsLogicalDayBoundary() throws {
        let container = try makeContainer(); let context = container.mainContext
        let area = habit(); context.insert(area)
        area.habitPausePeriods = [HabitPausePeriod(startsOn: wednesday, endsBefore: nil, createdAt: monday)]
        try context.save()
        let boundary = AppDayBoundary(hour: 4)
        let service = AreaLifecycleService(calendar: calendar, dayBoundary: boundary)
        try service.archive(area, modelContext: context, now: monday.addingTimeInterval(3 * 3600))
        try service.restore(area, modelContext: context, now: wednesday.addingTimeInterval(5 * 3600))
        #expect(area.habitPausePeriods.count == 2)
        #expect(area.habitPausePeriods.last?.startsOn == monday.addingTimeInterval(-86400))
        #expect(area.habitPausePeriods.last?.endsBefore == wednesday)
        #expect(HabitPauseService(calendar: calendar).isPaused(area, on: wednesday))
    }

    @Test func archiveAndRestoreFailureRestoreRetainedStateAndUnrelatedEdits() throws {
        let container = try makeContainer(); let context = container.mainContext
        let area = habit(); let other = Area(name: "Unrelated", type: .neutral)
        context.insert(area); context.insert(other)
        let todo = Todo(title: "", area: area, habitOccurrence: true, scheduledDate: monday)
        context.insert(todo); try context.save()
        other.name = "Pending"
        let failing = AreaLifecycleService(calendar: calendar, saveChanges: { _ in throw Failure.save })
        #expect(throws: Failure.self) { try failing.archive(area, modelContext: context, now: monday) }
        #expect(!area.isArchived); #expect(!todo.isDeleted); #expect(other.name == "Pending")
        try AreaLifecycleService(calendar: calendar).archive(area, modelContext: context, now: monday)
        #expect(throws: Failure.self) { try failing.restore(area, modelContext: context, now: wednesday) }
        #expect(area.archivedAt == monday); #expect(area.habitPausePeriods.isEmpty)
        let loaded = try #require(try ModelContext(container).fetch(FetchDescriptor<Area>()).first { $0.id == area.id })
        #expect(loaded.archivedAt == monday); #expect(loaded.habitPausePeriods.isEmpty)
    }

    @Test func systemAreaCannotBeArchivedOrRestored() throws {
        let container = try makeContainer(); let context = container.mainContext
        let inbox = DefaultAreas.makeTaskInbox(); context.insert(inbox); try context.save()
        #expect(throws: AreaLifecycleError.self) { try AreaLifecycleService().archive(inbox, modelContext: context) }
        #expect(throws: AreaLifecycleError.self) { try AreaLifecycleService().restore(inbox, modelContext: context) }
        #expect(!inbox.isArchived)
    }

    private func habit() -> Area {
        Area(name: "Study", type: .habit, goalTarget: 1, goalPeriod: .daily, goalUnit: .occurrences, goalSchedule: .everyDay)
    }
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private var monday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))! }
    private var wednesday: Date { monday.addingTimeInterval(2 * 86400) }
    private func makeContainer() throws -> ModelContainer {
        let schema = AppModelContainerFactory.schema
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }
    private enum Failure: Error { case save }
}

import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct HistoryTaskRecordTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func availableTodosIncludesZeroFlowTasksOnlyOnTheSelectedDate() {
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let area = Area(name: "運動", type: .habit)
        let selected = Todo(title: "筋トレ", area: area, scheduledDate: day)
        let anotherDay = Todo(
            title: "ランニング",
            area: area,
            scheduledDate: day.addingTimeInterval(86_400)
        )
        let noDate = Todo(title: "いつか", area: area)

        let result = HistoryTaskRecordEditor(calendar: calendar).availableTodos(
            on: day,
            from: [anotherDay, noDate, selected]
        )

        #expect(result.map(\.id) == [selected.id])
    }

    @Test func recordingExistingCheckboxStoresHistoricalCompletionWithoutFlow() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "運動", type: .habit)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(18 * 3_600)
        let todo = Todo(title: "筋トレ", area: area, scheduledDate: day)
        context.insert(area)
        context.insert(todo)

        let result = try HistoryTaskRecordEditor(calendar: calendar).record(
            todo: todo,
            recordedAt: recordedAt,
            mode: .twentyFiveFive,
            focusSeconds: 25 * 60,
            modelContext: context
        )

        #expect(result.flowSession == nil)
        #expect(todo.isCompleted)
        #expect(todo.actualProgress == 1)
        #expect(todo.completedAt == recordedAt)
        #expect(try context.fetch(FetchDescriptor<FlowSession>()).isEmpty)
    }

    @Test func recordingExistingMinuteTaskCreatesFlowAndMeasuredProgress() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "学習", type: .neutral)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(9 * 3_600)
        let todo = Todo(
            title: "日本語",
            area: area,
            measurement: .minutes,
            plannedAmount: 60,
            scheduledDate: day
        )
        context.insert(area)
        context.insert(todo)

        let result = try HistoryTaskRecordEditor(calendar: calendar).record(
            todo: todo,
            recordedAt: recordedAt,
            mode: .twentyFiveFive,
            focusSeconds: 30 * 60,
            modelContext: context
        )

        #expect(result.flowSession != nil)
        #expect(result.flowSession?.todo?.id == todo.id)
        #expect(todo.recordedFocusSeconds == 30 * 60)
        #expect(todo.actualProgress == 30)
        #expect(!todo.isCompleted)
    }

    @Test func flowContextCanLinkCheckboxTaskWithoutCompletingIt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(11 * 3_600)
        let todo = Todo(title: "確認", area: area, scheduledDate: day)
        context.insert(area)
        context.insert(todo)

        let result = try HistoryTaskRecordEditor(calendar: calendar).recordFlow(
            todo: todo,
            area: area,
            recordedAt: recordedAt,
            mode: .sprint,
            focusSeconds: 12 * 60,
            modelContext: context
        )

        #expect(result.flowSession?.todo?.id == todo.id)
        #expect(result.flowSession?.area?.id == area.id)
        #expect(!todo.isCompleted)
        #expect(todo.actualProgress == 0)
    }

    @Test func creatingHistoricalCheckboxCreatesAndCompletesTaskOnSelectedDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "仕事", type: .neutral)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(14 * 3_600)
        context.insert(area)

        let result = try HistoryTaskRecordEditor(calendar: calendar).createAndRecord(
            title: "提出",
            area: area,
            measurement: .checkbox,
            priority: .high,
            isRoomIfPossible: false,
            plannedAmount: nil,
            scheduledDate: day,
            recordedAt: recordedAt,
            mode: .sprint,
            focusSeconds: 12 * 60,
            modelContext: context
        )
        let todo = try #require(result.todo)

        #expect(result.flowSession == nil)
        #expect(todo.title == "提出")
        #expect(todo.isCompleted)
        #expect(todo.completedAt == recordedAt)
        #expect(calendar.isDate(todo.scheduledDate!, inSameDayAs: day))
    }

    @Test func creatingHistoricalBlockTaskCreatesLinkedFlow() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "学習", type: .neutral)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(10 * 3_600)
        context.insert(area)

        let result = try HistoryTaskRecordEditor(calendar: calendar).createAndRecord(
            title: "VPC",
            area: area,
            measurement: .focusBlocks,
            priority: .medium,
            isRoomIfPossible: false,
            plannedAmount: 2,
            scheduledDate: day,
            recordedAt: recordedAt,
            mode: .twentyFiveFive,
            focusSeconds: 25 * 60,
            modelContext: context
        )
        let todo = try #require(result.todo)

        #expect(result.flowSession?.todo?.id == todo.id)
        #expect(todo.actualProgress == 1)
        #expect(todo.plannedAmount == 2)
        #expect(!todo.isCompleted)
    }

    @Test func missingWeeklyHabitCanBeRecordedOnHistoricalDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(
            name: "筋トレ",
            type: .habit,
            symbolName: "💪",
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weeklyCount,
            weeklyTargetCount: 3
        )
        let monday = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let laterPendingTodo = Todo(
            title: "",
            area: area,
            scheduledDate: monday.addingTimeInterval(2 * 86_400)
        )
        context.insert(area)
        context.insert(laterPendingTodo)

        let result = try HistoryTaskRecordEditor(calendar: calendar).createHabitOccurrenceAndRecord(
            area: area,
            scheduledDate: monday,
            recordedAt: monday.addingTimeInterval(12 * 3_600),
            mode: .twentyFiveFive,
            focusSeconds: 25 * 60,
            modelContext: context
        )
        let todo = try #require(result.todo)

        #expect(result.flowSession == nil)
        #expect(todo.area?.id == area.id)
        #expect(todo.measurement == .checkbox)
        #expect(todo.isCompleted)
        #expect(calendar.isDate(todo.scheduledDate!, inSameDayAs: monday))
        #expect(try context.fetch(FetchDescriptor<Todo>()).count == 2)
    }

    @Test func flowContextCanCreateMissingHabitOccurrenceWithoutCompletingCheckbox() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(
            name: "筋トレ",
            type: .habit,
            symbolName: "💪",
            goalTarget: 1,
            goalPeriod: .weekly,
            goalUnit: .occurrences,
            goalSchedule: .weeklyCount,
            weeklyTargetCount: 3
        )
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        context.insert(area)

        let result = try HistoryTaskRecordEditor(calendar: calendar).createHabitOccurrenceAndRecordFlow(
            area: area,
            scheduledDate: day,
            recordedAt: day.addingTimeInterval(9 * 3_600),
            mode: .sprint,
            focusSeconds: 12 * 60,
            modelContext: context
        )
        let todo = try #require(result.todo)

        #expect(result.flowSession?.todo?.id == todo.id)
        #expect(todo.measurement == .checkbox)
        #expect(!todo.isCompleted)
        #expect(calendar.isDate(todo.scheduledDate!, inSameDayAs: day))
    }

    @Test func areaOnlyRecordCreatesFlowWithoutTodo() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let area = Area(name: "学習", type: .neutral)
        let recordedAt = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(area)

        let result = try HistoryTaskRecordEditor(calendar: calendar).record(
            area: area,
            recordedAt: recordedAt,
            mode: .sprint,
            focusSeconds: 12 * 60,
            modelContext: context
        )

        #expect(result.todo == nil)
        #expect(result.flowSession?.todo == nil)
        #expect(result.flowSession?.area?.id == area.id)
        #expect(result.flowSession?.actualFocusDurationSeconds == 12 * 60)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

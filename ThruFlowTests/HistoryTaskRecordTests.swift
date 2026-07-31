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
        let direction = Direction(name: "運動", type: .habit)
        let selected = Todo(title: "筋トレ", direction: direction, scheduledDate: day)
        let anotherDay = Todo(
            title: "ランニング",
            direction: direction,
            scheduledDate: day.addingTimeInterval(86_400)
        )
        let noDate = Todo(title: "いつか", direction: direction)

        let result = HistoryTaskRecordEditor(calendar: calendar).availableTodos(
            on: day,
            from: [anotherDay, noDate, selected]
        )

        #expect(result.map(\.id) == [selected.id])
    }

    @Test func recordingExistingCheckboxStoresHistoricalCompletionWithoutFlow() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let direction = Direction(name: "運動", type: .habit)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(18 * 3_600)
        let todo = Todo(title: "筋トレ", direction: direction, scheduledDate: day)
        context.insert(direction)
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
        let direction = Direction(name: "学習", type: .neutral)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(9 * 3_600)
        let todo = Todo(
            title: "日本語",
            direction: direction,
            measurement: .minutes,
            plannedAmount: 60,
            scheduledDate: day
        )
        context.insert(direction)
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
        let direction = Direction(name: "仕事", type: .neutral)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(11 * 3_600)
        let todo = Todo(title: "確認", direction: direction, scheduledDate: day)
        context.insert(direction)
        context.insert(todo)

        let result = HistoryTaskRecordEditor(calendar: calendar).recordFlow(
            todo: todo,
            direction: direction,
            recordedAt: recordedAt,
            mode: .sprint,
            focusSeconds: 12 * 60,
            modelContext: context
        )

        #expect(result.flowSession?.todo?.id == todo.id)
        #expect(result.flowSession?.direction?.id == direction.id)
        #expect(!todo.isCompleted)
        #expect(todo.actualProgress == 0)
    }

    @Test func creatingHistoricalCheckboxCreatesAndCompletesTaskOnSelectedDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let direction = Direction(name: "仕事", type: .neutral)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(14 * 3_600)
        context.insert(direction)

        let result = try HistoryTaskRecordEditor(calendar: calendar).createAndRecord(
            title: "提出",
            direction: direction,
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
        let direction = Direction(name: "学習", type: .neutral)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let recordedAt = day.addingTimeInterval(10 * 3_600)
        context.insert(direction)

        let result = try HistoryTaskRecordEditor(calendar: calendar).createAndRecord(
            title: "VPC",
            direction: direction,
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
        let direction = Direction(
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
            direction: direction,
            scheduledDate: monday.addingTimeInterval(2 * 86_400)
        )
        context.insert(direction)
        context.insert(laterPendingTodo)

        let result = try HistoryTaskRecordEditor(calendar: calendar).createHabitOccurrenceAndRecord(
            direction: direction,
            scheduledDate: monday,
            recordedAt: monday.addingTimeInterval(12 * 3_600),
            mode: .twentyFiveFive,
            focusSeconds: 25 * 60,
            modelContext: context
        )
        let todo = try #require(result.todo)

        #expect(result.flowSession == nil)
        #expect(todo.direction?.id == direction.id)
        #expect(todo.measurement == .checkbox)
        #expect(todo.isCompleted)
        #expect(calendar.isDate(todo.scheduledDate!, inSameDayAs: monday))
        #expect(try context.fetch(FetchDescriptor<Todo>()).count == 2)
    }

    @Test func flowContextCanCreateMissingHabitOccurrenceWithoutCompletingCheckbox() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let direction = Direction(
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
        context.insert(direction)

        let result = try HistoryTaskRecordEditor(calendar: calendar).createHabitOccurrenceAndRecordFlow(
            direction: direction,
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

    @Test func directionOnlyRecordCreatesFlowWithoutTodo() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let direction = Direction(name: "学習", type: .neutral)
        let recordedAt = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(direction)

        let result = HistoryTaskRecordEditor(calendar: calendar).record(
            direction: direction,
            recordedAt: recordedAt,
            mode: .sprint,
            focusSeconds: 12 * 60,
            modelContext: context
        )

        #expect(result.todo == nil)
        #expect(result.flowSession?.todo == nil)
        #expect(result.flowSession?.direction?.id == direction.id)
        #expect(result.flowSession?.actualFocusDurationSeconds == 12 * 60)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

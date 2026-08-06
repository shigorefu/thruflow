import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct FlowHistoryDeletionTests {
    @Test func deletingAllHistoryPreservesTaskDataAndResetsDerivedProgress() throws {
        let schema = Schema([
            Direction.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 100_000)
        let direction = Direction(name: "仕事", type: .neutral)
        let measuredTodo = Todo(
            title: "実装",
            notes: "残すメモ",
            direction: direction,
            measurement: .minutes,
            plannedAmount: 20
        )
        let checkTodo = Todo(
            title: "送信",
            direction: direction,
            measurement: .checkbox
        )
        let archivedTodo = Todo(
            title: "過去の実装",
            direction: direction,
            measurement: .minutes,
            plannedAmount: 20,
            actualProgress: 20,
            focusDurationSeconds: 20 * 60,
            status: .completed,
            completedAt: now
        )
        let deletedTodo = Todo(
            title: "削除済み",
            direction: direction,
            measurement: .minutes,
            plannedAmount: 10,
            actualProgress: 10,
            focusDurationSeconds: 10 * 60,
            status: .completed,
            completedAt: now
        )
        context.insert(direction)
        context.insert(measuredTodo)
        context.insert(checkTodo)
        context.insert(archivedTodo)
        context.insert(deletedTodo)
        checkTodo.setCompleted(true, now: now)
        archivedTodo.archive(now: now.addingTimeInterval(1))
        deletedTodo.softDelete(now: now.addingTimeInterval(2))

        let session = FlowHistoryEditor().createManual(
            todo: measuredTodo,
            direction: direction,
            mode: .twentyFiveFive,
            startedAt: now,
            focusSeconds: 25 * 60,
            modelContext: context,
            now: now.addingTimeInterval(25 * 60)
        )
        let flowBreak = FlowBreak(
            seriesID: session.seriesID ?? session.id,
            previousSessionID: session.id,
            startedAt: now.addingTimeInterval(25 * 60),
            plannedDurationSeconds: 5 * 60
        )
        context.insert(flowBreak)
        try context.save()

        let result = try FlowHistoryDeletionService().deleteAll(
            modelContext: context,
            now: now.addingTimeInterval(30 * 60)
        )

        #expect(result == FlowHistoryDeletionResult(deletedFlowCount: 1, deletedBreakCount: 1))
        #expect(try context.fetch(FetchDescriptor<FlowSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FlowSegment>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FlowBreak>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Todo>()).count == 4)
        #expect(try context.fetch(FetchDescriptor<Direction>()).count == 1)
        #expect(measuredTodo.recordedFocusSeconds == 0)
        #expect(measuredTodo.actualProgress == 0)
        #expect(measuredTodo.status == .active)
        #expect(measuredTodo.completedAt == nil)
        #expect(measuredTodo.notes == "残すメモ")
        #expect(checkTodo.isCompleted)
        #expect(checkTodo.completedAt == now)
        #expect(archivedTodo.isArchived)
        #expect(archivedTodo.status == .archived)
        #expect(archivedTodo.recordedFocusSeconds == 0)
        #expect(archivedTodo.actualProgress == 0)
        #expect(archivedTodo.completedAt == nil)
        #expect(deletedTodo.isDeleted)
        #expect(deletedTodo.recordedFocusSeconds == 0)
        #expect(deletedTodo.actualProgress == 0)
        #expect(direction.recordedFocusSeconds == 0)
    }

    @Test func deletingAllHistoryRejectsAnActiveFlowWithoutChangingData() throws {
        let schema = Schema([
            Direction.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 200_000)
        let direction = Direction(name: "仕事", type: .neutral)
        let session = FlowSession(
            direction: direction,
            mode: .twentyFiveFive,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        context.insert(direction)
        context.insert(session)
        try context.save()

        #expect(throws: FlowHistoryDeletionError.activeFlowExists) {
            try FlowHistoryDeletionService().deleteAll(modelContext: context)
        }
        #expect(try context.fetch(FetchDescriptor<FlowSession>()).count == 1)
        #expect(direction.recordedFocusSeconds == 0)
    }

    @Test func deletingAllHistoryRemovesAnOrphanedFlowAwaitingItsResult() throws {
        let schema = Schema([
            Direction.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 250_000)
        let direction = Direction(name: "仕事", type: .neutral)
        let session = FlowSession(
            direction: direction,
            mode: .twentyFiveFive,
            phase: .awaitingResult,
            status: .awaitingResult,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            endedAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            actualFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        context.insert(direction)
        context.insert(session)
        try context.save()

        let result = try FlowHistoryDeletionService().deleteAll(modelContext: context)

        #expect(result.deletedFlowCount == 1)
        #expect(try context.fetch(FetchDescriptor<FlowSession>()).isEmpty)
    }

    @Test func deletionActorPurgesPersistedHistoryAndIsIdempotent() async throws {
        let schema = Schema([
            Direction.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let startedAt = Date(timeIntervalSince1970: 300_000)
        let firstDeletionDate = startedAt.addingTimeInterval(30 * 60)
        let secondDeletionDate = firstDeletionDate.addingTimeInterval(60 * 60)
        let direction = Direction(name: "読書", type: .neutral)
        let todo = Todo(
            title: "本を読む",
            direction: direction,
            measurement: .minutes,
            plannedAmount: 25
        )
        context.insert(direction)
        context.insert(todo)
        FlowHistoryEditor().createManual(
            todo: todo,
            direction: direction,
            mode: .twentyFiveFive,
            startedAt: startedAt,
            focusSeconds: 25 * 60,
            modelContext: context,
            now: startedAt.addingTimeInterval(25 * 60)
        )
        try context.save()
        let deletionActor = FlowHistoryDeletionActor(modelContainer: container)

        let first = try await deletionActor.deleteAll(now: firstDeletionDate)
        let remainingSessions = try context.fetch(FetchDescriptor<FlowSession>())
        let retainedTodos = try context.fetch(FetchDescriptor<Todo>())
        let retainedDirections = try context.fetch(FetchDescriptor<Direction>())

        #expect(first == FlowHistoryDeletionResult(deletedFlowCount: 1, deletedBreakCount: 0))
        #expect(remainingSessions.isEmpty)
        #expect(retainedTodos.count == 1)
        #expect(retainedTodos[0].recordedFocusSeconds == 0)
        #expect(retainedTodos[0].actualProgress == 0)
        #expect(retainedDirections.count == 1)
        #expect(retainedDirections[0].recordedFocusSeconds == 0)

        let todoUpdatedAt = retainedTodos[0].updatedAt
        let directionUpdatedAt = retainedDirections[0].updatedAt
        let second = try await deletionActor.deleteAll(now: secondDeletionDate)

        #expect(second == FlowHistoryDeletionResult(deletedFlowCount: 0, deletedBreakCount: 0))
        #expect(retainedTodos[0].updatedAt == todoUpdatedAt)
        #expect(retainedDirections[0].updatedAt == directionUpdatedAt)
    }
}

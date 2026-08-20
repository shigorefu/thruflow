import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct AppDataResetTests {
    @Test func resetDeletesEveryPersistedUserEntity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 100_000)
        let direction = Direction(name: "仕事", type: .neutral)
        let archivedDirection = Direction(
            name: "過去",
            type: .nice,
            archivedAt: start
        )
        let todo = Todo(
            title: "実装",
            notes: "削除するメモ",
            direction: direction,
            measurement: .minutes,
            plannedAmount: 25
        )
        let deletedTodo = Todo(
            title: "削除済み",
            direction: archivedDirection,
            deletedAt: start
        )
        context.insert(direction)
        context.insert(archivedDirection)
        context.insert(todo)
        context.insert(deletedTodo)

        let session = FlowHistoryEditor().createManual(
            todo: todo,
            direction: direction,
            mode: .twentyFiveFive,
            startedAt: start,
            focusSeconds: 25 * 60,
            modelContext: context,
            now: start.addingTimeInterval(25 * 60)
        )
        context.insert(FlowBreak(
            seriesID: session.seriesID ?? session.id,
            previousSessionID: session.id,
            startedAt: start.addingTimeInterval(25 * 60),
            plannedDurationSeconds: 5 * 60
        ))
        try context.save()

        let result = try AppDataResetService().reset(modelContext: context)

        #expect(result == AppDataResetResult(
            deletedDirectionCount: 2,
            deletedTodoCount: 2,
            deletedFlowCount: 1,
            deletedBreakCount: 1
        ))
        #expect(try context.fetch(FetchDescriptor<Direction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Todo>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FlowSession>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FlowSegment>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FlowBreak>()).isEmpty)
    }

    @Test func resetRejectsAnActiveFlowWithoutChangingData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 200_000)
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "実装", direction: direction)
        let session = FlowSession(
            direction: direction,
            todo: todo,
            mode: .twentyFiveFive,
            startedAt: start,
            plannedEndAt: start.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        context.insert(direction)
        context.insert(todo)
        context.insert(session)
        try context.save()

        #expect(throws: AppDataResetError.activeFlowExists) {
            try AppDataResetService().reset(modelContext: context)
        }
        #expect(try context.fetch(FetchDescriptor<Direction>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Todo>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<FlowSession>()).count == 1)
    }

    @Test func resetActorIsIdempotent() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Direction(name: "読書", type: .neutral))
        try context.save()
        let actor = AppDataResetActor(modelContainer: container)

        let first = try await actor.reset()
        let second = try await actor.reset()

        #expect(first.deletedDirectionCount == 1)
        #expect(second == AppDataResetResult(
            deletedDirectionCount: 0,
            deletedTodoCount: 0,
            deletedFlowCount: 0,
            deletedBreakCount: 0
        ))
        #expect(try context.fetch(FetchDescriptor<Direction>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Direction.self,
            Todo.self,
            FlowSession.self,
            FlowSegment.self,
            FlowBreak.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

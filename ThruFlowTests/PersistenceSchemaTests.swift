import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct PersistenceSchemaTests {
    @Test func sharedSchemaPersistsCloudKitCompatibleRelationships() throws {
        let container = AppModelContainerFactory.make()
        let context = ModelContext(container)
        let direction = Direction(name: "仕事", type: .neutral)
        let todo = Todo(title: "資料を作る", direction: direction)
        let startedAt = Date(timeIntervalSince1970: 10_000)
        let session = FlowSession(
            direction: direction,
            todo: todo,
            mode: .twentyFiveFive,
            startedAt: startedAt,
            plannedEndAt: startedAt.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let segment = FlowSegment(
            session: session,
            direction: direction,
            todo: todo,
            startedAt: startedAt,
            startFocusSeconds: 0
        )
        session.segments = [segment]

        context.insert(direction)
        context.insert(todo)
        context.insert(session)
        try context.save()

        #expect(direction.todos?.map(\.id).contains(todo.id) == true)
        #expect(direction.flowSessions?.map(\.id).contains(session.id) == true)
        #expect(todo.flowSessions?.map(\.id).contains(session.id) == true)
        #expect(session.resolvedSegments.map(\.id) == [segment.id])
    }
}

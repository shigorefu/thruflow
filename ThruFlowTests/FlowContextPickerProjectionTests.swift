import Foundation
import Testing
@testable import ThruFlow

struct FlowContextPickerProjectionTests {
    @Test @MainActor func separatesTasksHabitsAndDirectionsUsingTheSharedPickerRules() {
        let start = Date(timeIntervalSince1970: 1_000)
        let other = DefaultDirections.makeTaskInbox(now: start)
        let habit = Direction(
            name: "運動",
            type: .habit,
            sortIndex: 2,
            createdAt: start,
            updatedAt: start
        )
        let normal = Direction(
            name: "仕事",
            type: .neutral,
            sortIndex: 1,
            createdAt: start,
            updatedAt: start
        )
        let nice = Direction(
            name: "読書",
            type: .nice,
            sortIndex: 0,
            createdAt: start,
            updatedAt: start
        )
        let archived = Direction(
            name: "旧方向",
            type: .neutral,
            createdAt: start,
            updatedAt: start,
            archivedAt: start
        )

        let firstTask = Todo(
            title: "先に表示",
            direction: normal,
            sortIndex: 0,
            createdAt: start
        )
        let completedTask = Todo(
            title: "完了済み",
            direction: normal,
            status: .completed,
            sortIndex: -1,
            createdAt: start.addingTimeInterval(1)
        )
        let niceTask = Todo(
            title: "余裕",
            direction: nice,
            createdAt: start.addingTimeInterval(2)
        )
        let habitTask = Todo(
            title: "走る",
            direction: habit,
            createdAt: start.addingTimeInterval(3)
        )
        let deletedTask = Todo(
            title: "削除済み",
            direction: normal,
            createdAt: start.addingTimeInterval(4),
            deletedAt: start
        )

        let projection = FlowContextPickerProjection(
            directions: [nice, archived, normal, other, habit],
            todos: [completedTask, habitTask, deletedTask, niceTask, firstTask]
        )

        #expect(projection.taskGroups.map(\.type) == [.neutral, .nice])
        #expect(projection.taskGroups[0].todos.map(\.id) == [firstTask.id, completedTask.id])
        #expect(projection.taskGroups[1].todos.map(\.id) == [niceTask.id])
        #expect(projection.habitTodos.map(\.id) == [habitTask.id])
        #expect(projection.otherDirection?.id == other.id)
        #expect(projection.userDirections.map(\.id) == [habit.id, normal.id, nice.id])
    }
}

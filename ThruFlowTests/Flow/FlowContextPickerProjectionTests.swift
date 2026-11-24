import Foundation
import Testing
@testable import ThruFlow

struct FlowContextPickerProjectionTests {
    @Test @MainActor func separatesTasksHabitsAndAreasUsingTheSharedPickerRules() {
        let start = Date(timeIntervalSince1970: 1_000)
        let other = DefaultAreas.makeTaskInbox(now: start)
        let habit = Area(
            name: "運動",
            type: .habit,
            sortIndex: 2,
            createdAt: start,
            updatedAt: start
        )
        let normal = Area(
            name: "仕事",
            type: .neutral,
            sortIndex: 1,
            createdAt: start,
            updatedAt: start
        )
        let nice = Area(
            name: "読書",
            type: .nice,
            sortIndex: 0,
            createdAt: start,
            updatedAt: start
        )
        let archived = Area(
            name: "旧方向",
            type: .neutral,
            createdAt: start,
            updatedAt: start,
            archivedAt: start
        )

        let firstTask = Todo(
            title: "先に表示",
            area: normal,
            sortIndex: 0,
            createdAt: start
        )
        let completedTask = Todo(
            title: "完了済み",
            area: normal,
            status: .completed,
            sortIndex: -1,
            createdAt: start.addingTimeInterval(1)
        )
        let niceTask = Todo(
            title: "余裕",
            area: nice,
            createdAt: start.addingTimeInterval(2)
        )
        let habitTask = Todo(
            title: "走る",
            area: habit,
            createdAt: start.addingTimeInterval(3)
        )
        let deletedTask = Todo(
            title: "削除済み",
            area: normal,
            createdAt: start.addingTimeInterval(4),
            deletedAt: start
        )

        let projection = FlowContextPickerProjection(
            areas: [nice, archived, normal, other, habit],
            todos: [completedTask, habitTask, deletedTask, niceTask, firstTask]
        )

        #expect(projection.taskGroups.map(\.type) == [.neutral, .nice])
        #expect(projection.taskGroups[0].todos.map(\.id) == [firstTask.id, completedTask.id])
        #expect(projection.taskGroups[1].todos.map(\.id) == [niceTask.id])
        #expect(projection.habitTodos.map(\.id) == [habitTask.id])
        #expect(projection.otherArea?.id == other.id)
        #expect(projection.userAreas.map(\.id) == [habit.id, normal.id, nice.id])
    }
}

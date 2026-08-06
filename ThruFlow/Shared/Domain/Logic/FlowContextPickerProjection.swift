import Foundation

@MainActor
struct FlowContextPickerTaskGroup: Identifiable {
    let type: DirectionType
    let todos: [Todo]

    var id: String { type.rawValue }
}

@MainActor
struct FlowContextPickerProjection {
    private static let taskGroupOrder: [DirectionType] = [.neutral, .nice]
    private static let directionOrder: [DirectionType] = [.habit, .neutral, .nice]

    let taskGroups: [FlowContextPickerTaskGroup]
    let habitTodos: [Todo]
    let otherDirection: Direction?
    let userDirections: [Direction]

    init(directions: [Direction], todos: [Todo]) {
        let activeDirections = directions.filter { !$0.isArchived }
        let activeTodos = todos.filter { !$0.isArchived && !$0.isDeleted }

        taskGroups = Self.taskGroupOrder.compactMap { type in
            let items = activeTodos
                .filter { ($0.direction?.type ?? .neutral) == type }
                .sorted(by: Self.sortTodos)
            guard !items.isEmpty else { return nil }
            return FlowContextPickerTaskGroup(type: type, todos: items)
        }
        habitTodos = activeTodos
            .filter { $0.direction?.type == .habit }
            .sorted(by: Self.sortTodos)
        otherDirection = DefaultDirections.existingTaskInbox(in: activeDirections)
        userDirections = activeDirections
            .filter { !DefaultDirections.isTaskInbox($0) }
            .sorted(by: Self.sortDirections)
    }

    nonisolated static func sortTodos(_ lhs: Todo, _ rhs: Todo) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }

        return lhs.createdAt < rhs.createdAt
    }

    private static func sortDirections(_ lhs: Direction, _ rhs: Direction) -> Bool {
        let lhsType = directionOrder.firstIndex(of: lhs.type) ?? directionOrder.count
        let rhsType = directionOrder.firstIndex(of: rhs.type) ?? directionOrder.count
        if lhsType != rhsType {
            return lhsType < rhsType
        }

        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

import Foundation

@MainActor
struct FlowContextPickerTaskGroup: Identifiable {
    let type: AreaType
    let todos: [Todo]

    var id: String { type.rawValue }
}

@MainActor
struct FlowContextPickerProjection {
    private static let taskGroupOrder: [AreaType] = [.neutral, .nice]
    private static let areaOrder: [AreaType] = [.habit, .neutral, .nice]

    let taskGroups: [FlowContextPickerTaskGroup]
    let habitTodos: [Todo]
    let otherArea: Area?
    let userAreas: [Area]

    init(areas: [Area], todos: [Todo]) {
        let activeAreas = areas.filter { !$0.isArchived }
        let activeTodos = todos.filter { !$0.isArchived && !$0.isDeleted }

        taskGroups = Self.taskGroupOrder.compactMap { type in
            let items = activeTodos
                .filter { ($0.area?.type ?? .neutral) == type }
                .sorted(by: Self.sortTodos)
            guard !items.isEmpty else { return nil }
            return FlowContextPickerTaskGroup(type: type, todos: items)
        }
        habitTodos = activeTodos
            .filter { $0.area?.type == .habit }
            .sorted(by: Self.sortTodos)
        otherArea = DefaultAreas.existingTaskInbox(in: activeAreas)
        userAreas = activeAreas
            .filter { !DefaultAreas.isTaskInbox($0) }
            .sorted(by: Self.sortAreas)
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

    private static func sortAreas(_ lhs: Area, _ rhs: Area) -> Bool {
        let lhsType = areaOrder.firstIndex(of: lhs.type) ?? areaOrder.count
        let rhsType = areaOrder.firstIndex(of: rhs.type) ?? areaOrder.count
        if lhsType != rhsType {
            return lhsType < rhsType
        }

        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

#if os(macOS)
import SwiftData
import SwiftUI

struct TasksTodoGroup: Identifiable {
    let type: AreaType
    let todos: [Todo]

    var id: String { type.rawValue }

    var title: String {
        switch type {
        case .habit:
            String(localized: "習慣一覧")
        case .neutral:
            String(localized: "通常")
        case .nice:
            String(localized: "ナイス")
        }
    }

    var tint: Color {
        switch type {
        case .habit:
            .red
        case .neutral:
            .blue
        case .nice:
            .green
        }
    }

    static let defaultOrderRaw = "habit,neutral,nice"

    static func order(from rawValue: String) -> [AreaType] {
        let parsed = rawValue
            .split(separator: ",")
            .compactMap { AreaType.normalized(rawValue: String($0)) }
        let missing = AreaType.allCases.filter { !parsed.contains($0) }
        return parsed.isEmpty ? [.habit, .neutral, .nice] : parsed + missing
    }

    static func groups(for todos: [Todo], order: [AreaType]) -> [TasksTodoGroup] {
        order.compactMap { type in
            let items = todos
                .filter { Self.type(for: $0) == type }
                .sorted(by: todoSort)
            guard !items.isEmpty else { return nil }
            return TasksTodoGroup(type: type, todos: items)
        }
    }

    static func type(for todo: Todo) -> AreaType {
        todo.taskType
    }

    nonisolated private static func todoSort(_ lhs: Todo, _ rhs: Todo) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }

        return lhs.createdAt < rhs.createdAt
    }
}

struct TasksSectionHeader: View {
    let group: TasksTodoGroup

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(group.tint)
                .frame(width: 7, height: 7)

            Text(group.title)
                .font(.caption.weight(.semibold))

            Text("\(group.todos.count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .textCase(nil)
    }
}

struct TasksOverdueHeader: View {
    let count: Int
    let onMoveAllToToday: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)

            Text(String(localized: "やり残し"))
                .font(.caption.weight(.semibold))

            Text("\(count)")
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())

            Spacer(minLength: 0)

            Button(String(localized: "すべて今日へ"), action: onMoveAllToToday)
                .font(.caption)
                .buttonStyle(.borderless)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .textCase(nil)
    }
}
#endif

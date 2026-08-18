import SwiftUI

struct IOSFlowContextPicker: View {
    @Environment(\.dismiss) private var dismiss

    let todos: [Todo]
    let directions: [Direction]
    let selectedTodoID: UUID?
    let selectedDirectionID: UUID?
    let select: (Direction, Todo?) -> Void

    @State private var selectedTab: IOSFlowContextPickerTab

    init(
        todos: [Todo],
        directions: [Direction],
        selectedTodoID: UUID?,
        selectedDirectionID: UUID?,
        select: @escaping (Direction, Todo?) -> Void
    ) {
        self.todos = todos
        self.directions = directions
        self.selectedTodoID = selectedTodoID
        self.selectedDirectionID = selectedDirectionID
        self.select = select

        let selectedTodo = todos.first { $0.id == selectedTodoID }
        _selectedTab = State(
            initialValue: selectedTodoID == nil
                ? .directions
                : selectedTodo?.direction?.type == .habit ? .habits : .tasks
        )
    }

    private var projection: FlowContextPickerProjection {
        FlowContextPickerProjection(directions: directions, todos: todos)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "表示"), selection: $selectedTab) {
                ForEach(IOSFlowContextPickerTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            List {
                switch selectedTab {
                case .tasks:
                    taskSections
                case .habits:
                    habitSection
                case .directions:
                    directionSection
                }
            }
            .listStyle(.insetGrouped)
            .animation(.snappy(duration: 0.22), value: selectedTab)
        }
        .iosCenteredNavigationTitle(String(localized: "Flowタスク"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "閉じる")) { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var taskSections: some View {
        if projection.taskGroups.isEmpty {
            emptyRow(String(localized: "今日のタスクはありません"), systemImage: "checklist")
        } else {
            ForEach(projection.taskGroups) { group in
                Section {
                    ForEach(group.todos) { todo in
                        taskRow(todo)
                    }
                } header: {
                    sectionHeader(title: group.type.displayName, count: group.todos.count)
                }
            }
        }
    }

    @ViewBuilder
    private var habitSection: some View {
        if projection.habitTodos.isEmpty {
            emptyRow(String(localized: "今日の習慣はありません"), systemImage: "repeat")
        } else {
            Section(String(localized: "習慣一覧")) {
                ForEach(projection.habitTodos) { todo in
                    taskRow(todo)
                }
            }
        }
    }

    @ViewBuilder
    private var directionSection: some View {
        let hasDirections = projection.otherDirection != nil || !projection.userDirections.isEmpty

        if !hasDirections {
            emptyRow(String(localized: "方向はありません"), systemImage: "point.3.connected.trianglepath.dotted")
        } else {
            Section(String(localized: "方向")) {
                if let otherDirection = projection.otherDirection {
                    directionRow(otherDirection)
                }

                ForEach(projection.userDirections) { direction in
                    directionRow(direction)
                }
            }
        }
    }

    private func taskRow(_ todo: Todo) -> some View {
        Group {
            if let direction = todo.direction {
                Button {
                    select(direction, todo)
                } label: {
                    row(
                        emoji: direction.symbolName,
                        title: TodoDisplay.title(for: todo),
                        subtitle: taskSubtitle(todo),
                        isSelected: selectedTodoID == todo.id,
                        isPlaceholder: todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func directionRow(_ direction: Direction) -> some View {
        Button {
            select(direction, nil)
        } label: {
            row(
                emoji: direction.symbolName,
                title: direction.name,
                subtitle: direction.type.displayName,
                isSelected: selectedTodoID == nil && selectedDirectionID == direction.id
            )
        }
        .buttonStyle(.plain)
    }

    private func row(
        emoji: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        isPlaceholder: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title2)
                .frame(width: 38, height: 38)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isPlaceholder ? .body.italic() : .body)
                    .foregroundStyle(isPlaceholder ? .secondary : .primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Text(verbatim: "\(count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func emptyRow(_ title: String, systemImage: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage)
            .frame(maxWidth: .infinity, minHeight: 220)
            .listRowBackground(Color.clear)
    }

    private func taskSubtitle(_ todo: Todo) -> String {
        let directionName = todo.direction?.name ?? String(localized: "その他")
        let priority = todo.priority == .low && todo.isRoomIfPossible
            ? String(localized: "余裕があれば")
            : todo.priority.displayName
        return String(localized: "\(directionName) · \(priority)")
    }
}

private enum IOSFlowContextPickerTab: String, CaseIterable, Identifiable {
    case tasks
    case habits
    case directions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:
            String(localized: "タスク")
        case .habits:
            String(localized: "習慣一覧")
        case .directions:
            String(localized: "方向")
        }
    }
}

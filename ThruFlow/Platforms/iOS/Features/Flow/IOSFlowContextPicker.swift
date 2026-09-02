import SwiftUI

struct IOSFlowContextPicker: View {
    @Environment(\.dismiss) private var dismiss

    let todos: [Todo]
    let areas: [Area]
    let selectedTodoID: UUID?
    let selectedAreaID: UUID?
    let select: (Area, Todo?) -> Void

    @State private var selectedTab: IOSFlowContextPickerTab

    init(
        todos: [Todo],
        areas: [Area],
        selectedTodoID: UUID?,
        selectedAreaID: UUID?,
        select: @escaping (Area, Todo?) -> Void
    ) {
        self.todos = todos
        self.areas = areas
        self.selectedTodoID = selectedTodoID
        self.selectedAreaID = selectedAreaID
        self.select = select

        let selectedTodo = todos.first { $0.id == selectedTodoID }
        _selectedTab = State(
            initialValue: selectedTodoID == nil
                ? .areas
                : selectedTodo?.area?.type == .habit ? .habits : .tasks
        )
    }

    private var projection: FlowContextPickerProjection {
        FlowContextPickerProjection(areas: areas, todos: todos)
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
                case .areas:
                    areaSection
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
    private var areaSection: some View {
        let hasAreas = projection.otherArea != nil || !projection.userAreas.isEmpty

        if !hasAreas {
            emptyRow(String(localized: "方向はありません"), systemImage: ProductSymbol.area)
        } else {
            Section(String(localized: "方向")) {
                if let otherArea = projection.otherArea {
                    areaRow(otherArea)
                }

                ForEach(projection.userAreas) { area in
                    areaRow(area)
                }
            }
        }
    }

    private func taskRow(_ todo: Todo) -> some View {
        Group {
            if let area = todo.area {
                Button {
                    select(area, todo)
                } label: {
                    row(
                        emoji: area.symbolName,
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

    private func areaRow(_ area: Area) -> some View {
        Button {
            select(area, nil)
        } label: {
            row(
                emoji: area.symbolName,
                title: area.name,
                subtitle: area.type.displayName,
                isSelected: selectedTodoID == nil && selectedAreaID == area.id
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
        let areaName = todo.area?.name ?? String(localized: "その他")
        let priority = todo.priority == .low && todo.isRoomIfPossible
            ? String(localized: "余裕があれば")
            : todo.priority.displayName
        return String(localized: "\(areaName) · \(priority)")
    }
}

private enum IOSFlowContextPickerTab: String, CaseIterable, Identifiable {
    case tasks
    case habits
    case areas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:
            String(localized: "タスク")
        case .habits:
            String(localized: "習慣一覧")
        case .areas:
            String(localized: "方向")
        }
    }
}

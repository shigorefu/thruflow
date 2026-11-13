#if os(macOS)
import AppKit
import Combine
import SwiftData
import SwiftUI

struct FlowTaskPickerView: View {
    let areas: [Area]
    let todos: [Todo]
    let selectedAreaID: UUID?
    let selectedTodoID: UUID?
    let onCreateTask: () -> Void
    let onSelect: (Area?, Todo?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: FlowTaskPickerTab = .tasks

    private var projection: FlowContextPickerProjection {
        FlowContextPickerProjection(areas: areas, todos: todos)
    }

    private var taskGroups: [FlowContextPickerTaskGroup] {
        projection.taskGroups
    }

    private var habitTodos: [Todo] {
        projection.habitTodos
    }

    private var otherArea: Area? {
        projection.otherArea
    }

    private var userAreas: [Area] {
        projection.userAreas
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "Flowタスク"))
                    .font(.headline.weight(.semibold))

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Picker(String(localized: "表示"), selection: $selectedTab) {
                ForEach(FlowTaskPickerTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ScrollView {
                switch selectedTab {
                case .tasks:
                    taskTab
                case .habits:
                    habitTab
                case .areas:
                    areaTab
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(14)
        .background(.bar)
    }

    @ViewBuilder
    private var taskTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                onCreateTask()
            } label: {
                Label(String(localized: "タスクを追加"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            if taskGroups.isEmpty {
                emptyState(String(localized: "今日のタスクはありません"))
            } else {
                ForEach(taskGroups) { group in
                    sectionHeader(title: group.title, count: group.todos.count, tint: group.tint)

                    VStack(spacing: 7) {
                        ForEach(group.todos) { todo in
                            taskRow(todo)
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var habitTab: some View {
        if habitTodos.isEmpty {
            emptyState(String(localized: "今日の習慣はありません"))
        } else {
            VStack(spacing: 7) {
                ForEach(habitTodos) { todo in
                    taskRow(todo)
                }
            }
            .padding(.top, 2)
        }
    }

    private var areaTab: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120, maximum: 170), spacing: 10)],
            alignment: .leading,
            spacing: 10
        ) {
            areaGridItem(
                iconText: otherArea?.symbolName ?? DefaultAreas.taskInboxSymbol,
                title: otherArea?.name ?? String(localized: "その他"),
                color: .secondary,
                isSelected: selectedTodoID == nil && (selectedAreaID == otherArea?.id || selectedAreaID == nil)
            ) {
                onSelect(otherArea, nil)
                dismiss()
            }

            ForEach(userAreas) { area in
                areaGridItem(
                    iconText: area.symbolName,
                    title: area.name,
                    color: Color(hex: area.colorHex),
                    isSelected: selectedTodoID == nil && selectedAreaID == area.id
                ) {
                    onSelect(area, nil)
                    dismiss()
                }
            }
        }
        .padding(.top, 2)
    }

    private func taskRow(_ todo: Todo) -> some View {
        Button {
            onSelect(todo.area, todo)
            dismiss()
        } label: {
            pickerRow(
                iconText: todo.area?.symbolName ?? DefaultAreas.taskInboxSymbol,
                title: TodoDisplay.flowTitle(for: todo),
                subtitle: taskSubtitle(todo),
                color: areaColor(todo.area),
                isSelected: selectedTodoID == todo.id,
                isPlaceholder: todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .buttonStyle(.plain)
    }

    private func areaGridItem(
        iconText: String,
        title: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(iconText)
                    .font(.system(size: 28))
                    .frame(width: 46, height: 46)
                    .background(color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(8)
            .background(isSelected ? color.opacity(0.14) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(color)
                        .padding(7)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? color.opacity(0.65) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func pickerRow(
        iconText: String,
        title: String,
        subtitle: String,
        color: Color,
        isSelected: Bool,
        isPlaceholder: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.16))

                Text(iconText)
                    .font(.title3)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isPlaceholder ? .body.weight(.semibold).italic() : .body.weight(.semibold))
                    .foregroundStyle(isPlaceholder ? Color.secondary.opacity(0.7) : Color.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func areaColor(_ area: Area?) -> Color {
        guard let area, !DefaultAreas.isTaskInbox(area) else {
            return .secondary
        }

        return Color(hex: area.colorHex)
    }

    private func taskSubtitle(_ todo: Todo) -> String {
        let areaName = TodoDisplay.flowContextName(for: todo)
        let priority = todo.priority == .low && todo.isRoomIfPossible ? String(localized: "余裕があれば") : todo.priority.displayName
        return String(localized: "\(areaName) · \(priority)")
    }

    private func sectionHeader(title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.caption.weight(.semibold))

            Text("\(count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
    }
}

private enum FlowTaskPickerTab: String, CaseIterable, Identifiable {
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

private extension FlowContextPickerTaskGroup {
    var title: String {
        type.displayName
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
}
#endif

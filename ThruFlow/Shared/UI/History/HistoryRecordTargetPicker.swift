#if os(macOS) || os(iOS)
import SwiftData
import SwiftUI

enum HistoryRecordTarget: Equatable {
    case todo(UUID)
    case habit(UUID)
    case area(UUID)
    case newTask
}

struct HistoryHabitOption: Identifiable {
    let area: Area
    let todo: Todo?

    var id: UUID { area.id }
}

private enum HistoryRecordPickerTab: String, CaseIterable, Identifiable {
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

struct HistoryRecordTargetPicker: View {
    let context: HistoryRecordContext
    let taskTodos: [Todo]
    let habitOptions: [HistoryHabitOption]
    let areas: [Area]
    let selectedTarget: HistoryRecordTarget?
    let onSelect: (HistoryRecordTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: HistoryRecordPickerTab

    init(
        context: HistoryRecordContext,
        taskTodos: [Todo],
        habitOptions: [HistoryHabitOption],
        areas: [Area],
        selectedTarget: HistoryRecordTarget?,
        onSelect: @escaping (HistoryRecordTarget) -> Void
    ) {
        self.context = context
        self.taskTodos = taskTodos
        self.habitOptions = habitOptions
        self.areas = areas
        self.selectedTarget = selectedTarget
        self.onSelect = onSelect

        let initialTab: HistoryRecordPickerTab
        switch selectedTarget {
        case .habit:
            initialTab = .habits
        case .area:
            initialTab = .areas
        case .todo, .newTask, nil:
            initialTab = context == .area ? .areas : .tasks
        }
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "記録対象"))
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if availableTabs.count > 1 {
                Picker(String(localized: "記録対象"), selection: $selectedTab) {
                    ForEach(availableTabs) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

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
        .padding(16)
        .background(.bar)
    }

    private var availableTabs: [HistoryRecordPickerTab] {
        switch context {
        case .flow:
            [.tasks, .habits, .areas]
        case .task:
            [.tasks, .habits]
        case .area:
            [.areas]
        }
    }

    private var taskTab: some View {
        VStack(spacing: 8) {
            if context == .task {
                targetRow(
                    emoji: "＋",
                    title: String(localized: "新しいタスク"),
                    subtitle: String(localized: "選択した日にタスクを作成"),
                    tint: .accentColor,
                    isSelected: selectedTarget == .newTask
                ) {
                    onSelect(.newTask)
                }
            }

            if taskTodos.isEmpty {
                emptyState(String(localized: "この日のタスクはありません"))
            } else {
                ForEach(taskTodos) { todo in
                    targetRow(
                        emoji: todo.area?.symbolName ?? DefaultAreas.taskInboxSymbol,
                        title: TodoDisplay.title(for: todo),
                        subtitle: todo.area?.name ?? String(localized: "その他"),
                        tint: areaColor(todo.area),
                        isSelected: selectedTarget == .todo(todo.id)
                    ) {
                        onSelect(.todo(todo.id))
                    }
                }
            }
        }
    }

    private var habitTab: some View {
        VStack(spacing: 8) {
            if habitOptions.isEmpty {
                emptyState(String(localized: "この日の習慣はありません"))
            } else {
                ForEach(habitOptions) { option in
                    targetRow(
                        emoji: option.area.symbolName,
                        title: TodoDisplay.title(for: option.todo, area: option.area),
                        subtitle: habitSubtitle(option),
                        tint: areaColor(option.area),
                        isSelected: selectedTarget == .habit(option.id)
                    ) {
                        onSelect(.habit(option.id))
                    }
                }
            }
        }
    }

    private var areaTab: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120, maximum: 170), spacing: 10)],
            spacing: 10
        ) {
            ForEach(areas) { area in
                Button {
                    onSelect(.area(area.id))
                } label: {
                    VStack(spacing: 8) {
                        Text(area.symbolName)
                            .font(.system(size: 28))
                            .frame(width: 46, height: 46)
                            .background(areaColor(area).opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(area.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(height: 32, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .padding(8)
                    .background(
                        selectedTarget == .area(area.id)
                            ? areaColor(area).opacity(0.14)
                            : Color.primary.opacity(0.05)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                selectedTarget == .area(area.id)
                                    ? areaColor(area).opacity(0.65)
                                    : .clear,
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func targetRow(
        emoji: String,
        title: String,
        subtitle: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(10)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func habitSubtitle(_ option: HistoryHabitOption) -> String {
        guard let todo = option.todo else {
            return String(localized: "この日に記録なし")
        }
        guard todo.measurement != .checkbox else { return "" }
        return TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: todo.recordedFocusSeconds
        )
    }

    private func areaColor(_ area: Area?) -> Color {
        guard let area, !DefaultAreas.isTaskInbox(area) else {
            return .secondary
        }
        return Color(hex: area.colorHex)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 220)
    }
}

private extension TodoDisplay {
    static func title(for todo: Todo?, area: Area) -> String {
        guard let todo else { return "(\(area.name))" }
        return title(for: todo)
    }
}

#endif

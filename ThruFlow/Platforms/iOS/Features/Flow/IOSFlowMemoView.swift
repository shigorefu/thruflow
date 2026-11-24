import SwiftData
import SwiftUI

struct IOSFlowMemoView: View {
    @Query(filter: #Predicate<Todo> { $0.deletedAt == nil }, sort: \Todo.updatedAt, order: .reverse)
    private var suggestionTodos: [Todo]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var memo = ""
    @State private var taskTitle: String
    @State private var selectedProject: Project?
    @State private var isEditingTaskTitle = false
    @FocusState private var isTaskTitleFocused: Bool
    private let todo: Todo?

    // Intentional one-time draft: cancel never edits the persisted Task.
    init(isBreakMemo: Bool, isTaskSwitchMemo: Bool = false, todo: Todo?, cancel: @escaping () -> Void,
         submit: @escaping (String?, String?, Project?) -> Void) {
        self.isBreakMemo = isBreakMemo
        self.isTaskSwitchMemo = isTaskSwitchMemo
        self.todo = todo
        _taskTitle = State(initialValue: todo?.title ?? "")
        self.cancel = cancel
        self.submit = submit
    }

    let isBreakMemo: Bool
    let isTaskSwitchMemo: Bool
    let cancel: () -> Void
    let submit: (String?, String?, Project?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(isTaskSwitchMemo ? String(localized: "メモ") : String(localized: "お疲れ様です。メモを追加しますか？"))
                        .font(.title2.bold())

                    if isTaskSwitchMemo {
                        Text(String(localized: "タスクを切り替える前にメモを残せます。入力中も現在のタスクの時間を記録します。"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let todo {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "タスク名"))
                                .font(.subheadline.weight(.medium))
                            TextField(String(localized: "タスク名"), text: taskTitleInput)
                                .textFieldStyle(.roundedBorder)
                                .focused($isTaskTitleFocused)
                                .onChange(of: isTaskTitleFocused) { _, isFocused in
                                    if !isFocused { isEditingTaskTitle = false }
                                }

                            VStack(spacing: 0) {
                                taskTitleSuggestions(excluding: todo.id)
                            }
                            .animation(reduceMotion ? nil : .smooth(duration: 0.16), value: isTaskTitleFocused && isEditingTaskTitle)
                        }
                    }
                    FlowMemoProjectPicker(todo: todo, selection: $selectedProject)
                        .pickerStyle(.menu)

                    Text(String(localized: "取り組んだこと"))
                        .font(.subheadline.weight(.medium))
                    TextField(String(localized: "何をしましたか"), text: $memo, axis: .vertical)
                        .lineLimit(5...9)
                        .padding(14)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Button(String(localized: "キャンセル"), action: cancel)
                        Spacer()
                        Button(memoIsEmpty ? String(localized: "メモなしで送信") : String(localized: "メモを保存して続ける")) {
                            submit(memoIsEmpty ? nil : memo, todo != nil ? taskTitle : nil, selectedProject)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
            }
            .iosCenteredNavigationTitle(
                isTaskSwitchMemo ? String(localized: "メモ")
                    : isBreakMemo ? String(localized: "休憩") : String(localized: "Flow完了")
            )
        }
    }

    private var taskTitleInput: Binding<String> {
        Binding(
            get: { taskTitle },
            set: { newTitle in
                guard newTitle != taskTitle else { return }
                taskTitle = newTitle
                isEditingTaskTitle = true
            }
        )
    }

    @ViewBuilder
    private func taskTitleSuggestions(excluding todoID: UUID) -> some View {
        if isTaskTitleFocused && isEditingTaskTitle {
            let suggestions = TaskTitleSuggestionBuilder().suggestions(
                query: taskTitle,
                todos: suggestionTodos,
                excludingTodoID: todoID,
                limit: 3
            )
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            taskTitle = suggestion.title
                            isEditingTaskTitle = false
                            isTaskTitleFocused = true
                        } label: {
                            Label(suggestion.title, systemImage: "clock.arrow.circlepath")
                                .font(.subheadline)
                                .lineLimit(2)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            }
        }
    }

    private var memoIsEmpty: Bool {
        memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

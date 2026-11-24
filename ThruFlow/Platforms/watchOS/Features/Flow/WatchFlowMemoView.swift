#if os(watchOS)
import Foundation
import SwiftData
import SwiftUI

struct WatchFlowMemoView: View {
    @Query(filter: #Predicate<Todo> { $0.deletedAt == nil }, sort: \Todo.updatedAt, order: .reverse)
    private var suggestionTodos: [Todo]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @State private var memo = ""
    @State private var taskTitle: String
    @State private var taskProject: Project?
    @State private var showsTitleSuggestions = false
    private let todo: Todo?
    private let taskSwitchID: UUID?
    let onComplete: () -> Void

    init(todo: Todo?, taskSwitchID: UUID?, onComplete: @escaping () -> Void) {
        self.todo = todo
        self.taskSwitchID = taskSwitchID
        self.onComplete = onComplete
        _taskTitle = State(initialValue: todo?.title ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if taskSwitchID != nil {
                    Text(String(localized: "タスクを切り替える前にメモを残せます。入力中も現在のタスクの時間を記録します。"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let todo {
                    Section(String(localized: "タスク名")) {
                        TextField(String(localized: "タスク名"), text: titleInput)
                        if showsTitleSuggestions {
                            ForEach(titleSuggestions(excluding: todo.id)) { suggestion in
                                Button {
                                    taskTitle = suggestion.title
                                    showsTitleSuggestions = false
                                } label: {
                                    Label(suggestion.title, systemImage: "clock.arrow.circlepath")
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
                FlowMemoProjectPicker(todo: todo, selection: $taskProject)
                Section(String(localized: "取り組んだこと")) {
                    TextField(String(localized: "何をしましたか"), text: $memo)
                }

                Button(String(localized: "メモを保存して続ける")) {
                    submit(memo)
                }

                Button(String(localized: "メモなしで送信")) {
                    submit(nil)
                }

                Button(String(localized: "キャンセル"), role: .cancel) {
                    cancel()
                }
            }
            .navigationTitle(String(localized: "メモ"))
        }
    }

    // The system Watch text editor returns the draft when entry ends.
    private var titleInput: Binding<String> {
        Binding(
            get: { taskTitle },
            set: { title in
                guard taskTitle != title else { return }
                taskTitle = title
                showsTitleSuggestions = true
            }
        )
    }

    private func titleSuggestions(excluding todoID: UUID) -> [TaskTitleSuggestion] {
        TaskTitleSuggestionBuilder().suggestions(
            query: taskTitle,
            todos: suggestionTodos,
            excludingTodoID: todoID,
            limit: 3
        )
    }

    private func submit(_ value: String?) {
        let didSave: Bool
        if let taskSwitchID {
            guard activeFlowStore.pendingTaskSwitch?.id == taskSwitchID else {
                onComplete()
                dismiss()
                return
            }
            didSave = activeFlowStore.completeTaskSwitchMemo(
                value, taskTitle: taskTitle, taskProject: taskProject, modelContext: modelContext
            )
        } else if activeFlowStore.isAwaitingBreakMemo {
            didSave = activeFlowStore.completeBreakMemo(value, taskTitle: taskTitle, taskProject: taskProject, modelContext: modelContext)
        } else {
            didSave = activeFlowStore.completeResult(value, taskTitle: taskTitle, taskProject: taskProject, modelContext: modelContext)
        }
        guard didSave else { return }
        onComplete()
        dismiss()
    }

    private func cancel() {
        if let taskSwitchID {
            if activeFlowStore.pendingTaskSwitch?.id == taskSwitchID {
                activeFlowStore.cancelTaskSwitchMemo()
            }
        } else if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.cancelBreakMemo()
        } else {
            activeFlowStore.cancelResultMemo(modelContext: modelContext)
        }
        onComplete()
        dismiss()
    }
}
#endif

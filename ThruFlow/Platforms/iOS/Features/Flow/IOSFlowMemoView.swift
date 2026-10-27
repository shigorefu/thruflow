import SwiftUI

struct IOSFlowMemoView: View {
    @State private var memo = ""
    @State private var taskTitle: String
    @State private var selectedProject: Project?
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

                    if todo != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "タスク名"))
                                .font(.subheadline.weight(.medium))
                            TextField(String(localized: "タスク名"), text: $taskTitle)
                                .textFieldStyle(.roundedBorder)
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

    private var memoIsEmpty: Bool {
        memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

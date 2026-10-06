import SwiftUI

struct IOSFlowMemoView: View {
    @State private var memo = ""
    @State private var taskTitle: String
    private let hasTask: Bool

    // Intentional one-time draft: cancel never edits the persisted Task.
    init(isBreakMemo: Bool, taskTitle: String?, cancel: @escaping () -> Void,
         submit: @escaping (String?, String?) -> Void) {
        self.isBreakMemo = isBreakMemo
        self.hasTask = taskTitle != nil
        _taskTitle = State(initialValue: taskTitle ?? "")
        self.cancel = cancel
        self.submit = submit
    }

    let isBreakMemo: Bool
    let cancel: () -> Void
    let submit: (String?, String?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(String(localized: "お疲れ様です。メモを追加しますか？"))
                        .font(.title2.bold())

                    if hasTask {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "タスク名"))
                                .font(.subheadline.weight(.medium))
                            TextField(String(localized: "タスク名"), text: $taskTitle)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
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
                            submit(memoIsEmpty ? nil : memo, hasTask ? taskTitle : nil)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
            }
            .iosCenteredNavigationTitle(
                isBreakMemo ? String(localized: "休憩") : String(localized: "Flow完了")
            )
        }
    }

    private var memoIsEmpty: Bool {
        memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

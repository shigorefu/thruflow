import SwiftUI

struct IOSFlowMemoView: View {
    @State private var memo = ""

    let isBreakMemo: Bool
    let cancel: () -> Void
    let submit: (String?) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(String(localized: "お疲れ様です。メモを追加しますか？"))
                    .font(.title2.bold())

                TextField(String(localized: "何をしましたか"), text: $memo, axis: .vertical)
                    .lineLimit(5...9)
                    .padding(14)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                Spacer()

                HStack {
                    Button(String(localized: "キャンセル"), action: cancel)
                    Spacer()
                    Button(memoIsEmpty ? String(localized: "メモなしで送信") : String(localized: "送信")) {
                        submit(memoIsEmpty ? nil : memo)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .navigationTitle(isBreakMemo ? String(localized: "休憩") : String(localized: "Flow完了"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var memoIsEmpty: Bool {
        memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

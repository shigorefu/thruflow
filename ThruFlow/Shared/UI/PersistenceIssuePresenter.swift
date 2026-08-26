import SwiftUI

private struct PersistenceIssuePresenter: ViewModifier {
    @ObservedObject private var issueCenter = PersistenceIssueCenter.shared

    func body(content: Content) -> some View {
        content.alert(
            title,
            isPresented: issueBinding
        ) {
            Button(String(localized: "OK"), role: .cancel) {
                issueCenter.dismissCurrentIssue()
            }
        } message: {
            Text(message)
        }
    }

    private var title: String {
        switch issueCenter.currentIssue?.operation {
        case .dataLoad:
            String(localized: "データを読み込めませんでした。")
        case .export:
            String(localized: "書き出せませんでした。")
        default:
            String(localized: "記録を保存できませんでした。")
        }
    }

    private var message: String {
        switch issueCenter.currentIssue?.operation {
        case .dataLoad, .export:
            String(localized: "もう一度お試しください。")
        default:
            String(localized: "変更内容は保存されていません。もう一度お試しください。")
        }
    }

    private var issueBinding: Binding<Bool> {
        Binding(
            get: { issueCenter.currentIssue != nil },
            set: { isPresented in
                if !isPresented {
                    issueCenter.dismissCurrentIssue()
                }
            }
        )
    }
}

extension View {
    func persistenceIssuePresenter() -> some View {
        modifier(PersistenceIssuePresenter())
    }
}

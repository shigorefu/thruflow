#if os(macOS) || os(iOS)
import SwiftUI

struct ExternalTaskSourceLink: View {
    let todo: Todo

    var body: some View {
        if let link = todo.externalTaskLink {
            VStack(alignment: .leading, spacing: 6) {
                if link.provider == .todoist, let url = link.originalURL,
                   url.scheme == "https", url.host == "app.todoist.com" {
                    Link(destination: url) {
                        HStack(alignment: .center, spacing: 8) {
                            ConnectorProviderLogo(provider: link.provider, size: 16)
                            Text(String(localized: "Todoistで開く"))
                        }
                    }
                } else {
                    HStack(alignment: .center, spacing: 8) {
                        ConnectorProviderLogo(provider: link.provider, size: 16)
                        Text(link.provider.connectorTitle)
                    }
                    .foregroundStyle(.secondary)
                }
                if todo.measurement == .checkbox {
                    Text(String(localized: "完了・未完了は接続先と同期します。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if link.completionChanges?.isEmpty == false {
                        Label(String(localized: "完了状態の送信待ち"), systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(String(localized: "分・ブロック形式の進捗はThruFlow内で管理します。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(String(localized: "タイトルと期限は接続先から更新されます。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif

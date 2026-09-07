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
                Text(String(localized: "タイトルと期限は接続先から更新されます。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif

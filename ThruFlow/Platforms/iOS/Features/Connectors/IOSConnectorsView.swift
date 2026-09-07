#if os(iOS)
import SwiftData
import SwiftUI

struct IOSConnectorsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var connectors: ConnectorStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "外部サービスのタスクを取り込み、ThruFlowで集中できます。"))
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach([ConnectorProviderID.reminders, .todoist], id: \.self) { provider in
                        NavigationLink {
                            IOSConnectorDetailView(provider: provider)
                        } label: {
                            ConnectorProviderRow(
                                provider: provider,
                                connection: connectors.connection(for: provider)
                            )
                        }
                        .accessibilityIdentifier("connectors.provider.\(provider.rawValue)")
                    }
                } footer: {
                    Text(String(localized: "接続するサービスと取り込み元を選んでください。"))
                }
            }
            .listStyle(.insetGrouped)
            .iosCenteredNavigationTitle(String(localized: "コネクタ"))
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "完了")) { dismiss() }
                    .accessibilityIdentifier("connectors.done")
            }
        }
    }
}

private struct IOSConnectorDetailView: View {
    let provider: ConnectorProviderID
    @Query(sort: \Area.sortIndex) private var areas: [Area]

    var body: some View {
        Form {
            ConnectorSetupSections(provider: provider, areas: areas)
        }
        .iosCenteredNavigationTitle(provider.connectorTitle)
    }
}
#endif

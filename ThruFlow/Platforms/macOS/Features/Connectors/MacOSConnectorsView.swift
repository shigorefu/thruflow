#if os(macOS)
import SwiftData
import SwiftUI

struct MacOSConnectorsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var connectors: ConnectorStore

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "外部サービスのタスクを取り込み、ThruFlowで集中できます。"))
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach([ConnectorProviderID.reminders, .todoist], id: \.self) { provider in
                        NavigationLink {
                            MacOSConnectorDetailView(provider: provider)
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
            .formStyle(.grouped)
            .navigationTitle(String(localized: "コネクタ"))
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "完了")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("connectors.done")
            }
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 480, idealHeight: 650)
    }
}

private struct MacOSConnectorDetailView: View {
    let provider: ConnectorProviderID
    @Query(sort: \Area.sortIndex) private var areas: [Area]

    var body: some View {
        Form {
            ConnectorSetupSections(provider: provider, areas: areas)
        }
        .formStyle(.grouped)
        .navigationTitle(provider.connectorTitle)
    }
}
#endif

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
                    Text(String(localized: "タスクの取り込みや集中時間の共有に使うサービスを選べます。"))
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach([ConnectorProviderID.reminders, .todoist, .toggl], id: \.self) { provider in
                        NavigationLink {
                            MacOSConnectorDetailView(provider: provider)
                        } label: {
                            if provider == .toggl {
                                TogglConnectorRow(store: connectors.toggl)
                            } else {
                                ConnectorProviderRow(
                                    provider: provider,
                                    connection: connectors.connection(for: provider)
                                )
                            }
                        }
                        .accessibilityIdentifier("connectors.provider.\(provider.rawValue)")
                    }
                } footer: {
                    Text(String(localized: "サービスごとに接続を設定できます。"))
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
    @EnvironmentObject private var connectors: ConnectorStore
    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @State private var hasContinuedToToggl = false

    var body: some View {
        Form {
            if provider == .toggl {
                if hasContinuedToToggl {
                    TogglSetupSections(store: connectors.toggl, areas: areas)
                } else {
                    Section { TogglConnectorRow(store: connectors.toggl) }
                }
            } else {
                ConnectorSetupSections(provider: provider, areas: areas)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(provider.connectorTitle)
        .modifier(TogglKeychainExplanation(
            isRequired: provider == .toggl,
            hasContinued: $hasContinuedToToggl
        ))
    }
}
#endif

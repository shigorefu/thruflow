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
                    Text(String(localized: "タスクの取り込みや集中時間の共有に使うサービスを選べます。"))
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach([ConnectorProviderID.reminders, .todoist, .toggl], id: \.self) { provider in
                        NavigationLink {
                            IOSConnectorDetailView(provider: provider, onDone: { dismiss() })
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
            .listStyle(.insetGrouped)
            .iosCenteredNavigationTitle(String(localized: "コネクタ"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完了")) { dismiss() }
                        .accessibilityIdentifier("connectors.done")
                }
            }
        }
    }
}

private struct IOSConnectorDetailView: View {
    let provider: ConnectorProviderID
    let onDone: () -> Void
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
        .iosCenteredNavigationTitle(provider.connectorTitle)
        .modifier(TogglKeychainExplanation(
            isRequired: provider == .toggl,
            hasContinued: $hasContinuedToToggl
        ))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "完了"), action: onDone)
                    .accessibilityIdentifier("connectors.done")
            }
        }
    }
}
#endif

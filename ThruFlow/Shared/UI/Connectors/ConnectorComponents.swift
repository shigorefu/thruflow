#if os(macOS) || os(iOS)
import SwiftData
import SwiftUI

extension ConnectorProviderID {
    var connectorTitle: String {
        switch self {
        case .reminders: String(localized: "Appleリマインダー")
        case .todoist: "Todoist"
        case .toggl: "Toggl Track"
        }
    }

    var connectorAssetName: String {
        switch self {
        case .reminders: "ConnectorRemindersLogo"
        case .todoist: "ConnectorTodoistLogo"
        case .toggl: "ConnectorTogglLogo"
        }
    }

    var connectorDescription: String {
        switch self {
        case .reminders:
            String(localized: "選んだリストの未完了リマインダーをタスクに取り込みます。")
        case .todoist:
            String(localized: "選んだプロジェクトの未完了タスクを取り込みます。")
        case .toggl:
            String(localized: "完了した集中時間をToggl Trackに送信します。")
        }
    }
}

/// Original vendor artwork; the adjacent provider name supplies its accessible label.
struct ConnectorProviderLogo: View {
    let provider: ConnectorProviderID
    var size: CGFloat = 28

    var body: some View {
        // Apple's bundled icon includes its standard transparent inset. Account for
        // that inset without cropping the artwork, so both visible marks align.
        let artworkSize = provider == .reminders ? size * 1.25 : size
        Image(decorative: provider.connectorAssetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: artworkSize, height: artworkSize)
            // Todoist requires half the mark height as clear space on every side.
            .frame(width: size * 2, height: size * 2)
            .accessibilityHidden(true)
    }
}

struct ConnectorProviderRow: View {
    let provider: ConnectorProviderID
    let connection: ConnectorConnection?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ConnectorProviderLogo(provider: provider)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(provider.connectorTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    ConnectorBetaBadge()
                }
                if connection != nil {
                    Label(String(localized: "接続済み"), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// Shared form fields; each platform owns its Form and navigation presentation.
struct ConnectorSetupSections: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectors: ConnectorStore

    let provider: ConnectorProviderID
    let areas: [Area]

    @State private var sourceAreaIDs: [String: UUID] = [:]
    @State private var showsDisconnectConfirmation = false
    @State private var didLoadDraft = false

    private var connection: ConnectorConnection? {
        connectors.connection(for: provider)
    }

    private var availableSources: [ConnectorSource] {
        connectors.sources[provider] ?? []
    }

    private var availableAreas: [Area] {
        areas.filter { !$0.isArchived && $0.type != .habit }
    }

    private var isBusy: Bool {
        connectors.busyProvider != nil
    }

    private var hasValidSelection: Bool {
        let areaIDs = Set(availableAreas.map(\.id))
        return Set(sourceAreaIDs.keys).isSubset(of: Set(availableSources.map(\.id))) &&
            sourceAreaIDs.values.allSatisfy { areaIDs.contains($0) }
    }

    var body: some View {
        Group {
            Section {
                ConnectorProviderRow(provider: provider, connection: connection)
                    .task {
                        guard !didLoadDraft else { return }
                        didLoadDraft = true
                        connectors.errorMessage = nil
                        restoreSelection()
                        if connection != nil {
                            await connectors.loadSources(for: provider)
                        }
                    }
                    .onChange(of: connection?.account.id) { _, _ in
                        restoreSelection()
                    }


                if connection == nil {
                    authorization
                } else if provider == .todoist {
                    Button(String(localized: "Todoistに再接続")) {
                        Task {
                            await connectors.authorizeTodoist()
                            restoreSelection()
                        }
                    }
                    .disabled(isBusy)
                    .accessibilityIdentifier("connectors.reauthorize.todoist")
                }
            }

            if let connection {
                sourceSelection
                synchronization(connection)
                disconnectSection
            }

            if connectors.busyProvider == provider {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(String(localized: "接続を更新しています…"))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("connectors.progress")
                }
            }

            if let message = connectors.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("connectors.error")
                }
            }
        }
    }

    @ViewBuilder
    private var authorization: some View {
        if provider == .todoist {
            Text(String(localized: "Todoistの画面でログインし、アクセスを許可します。ThruFlowのアカウント登録は不要です。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("connectors.todoist.explanation")
        } else {
            Text(String(localized: "リマインダーへのアクセスを許可した後、取り込むリストを選べます。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Button {
            Task {
                if provider == .reminders {
                    await connectors.connectReminders()
                } else {
                    await connectors.authorizeTodoist()
                }
                restoreSelection()
            }
        } label: {
            Text(provider == .todoist
                 ? String(localized: "Todoistに接続")
                 : String(localized: "リマインダーに接続"))
        }
        .buttonStyle(.borderedProminent)
        .disabled(isBusy)
        .accessibilityIdentifier("connectors.authorize.\(provider.rawValue)")
    }

    private var sourceSelection: some View {
        Section {
            ConnectorMappingColumnHeaders(destination: provider == .reminders
                ? String(localized: "リスト") : String(localized: "プロジェクト"))
            ForEach(availableAreas) { area in
                ConnectorAreaMappingRow(area: area) {
                    Menu {
                        Button(String(localized: "取り込まない")) {
                            sourceAreaIDs = sourceAreaIDs.filter { $0.value != area.id }
                        }
                        ForEach(availableSources) { source in
                            Toggle(source.name, isOn: Binding(
                                get: { sourceAreaIDs[source.id] == area.id },
                                set: { selected in
                                    if selected { sourceAreaIDs[source.id] = area.id }
                                    else { sourceAreaIDs.removeValue(forKey: source.id) }
                                }
                            ))
                            .disabled(sourceAreaIDs[source.id].map { $0 != area.id } ?? false)
                        }
                    } label: {
                        Text(selectionTitle(for: area))
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityLabel(area.name)
                    .accessibilityValue(selectionTitle(for: area))
                    .accessibilityIdentifier("connectors.mapping.\(area.id)")
                    .disabled(isBusy)
                }
            }
            if availableSources.isEmpty && !isBusy {
                Text(String(localized: "取り込み元がありません。リストやプロジェクトを確認して、再読み込みしてください。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Task { await connectors.loadSources(for: provider) }
            } label: {
                Label(String(localized: "取り込み元を再読み込み"), systemImage: "arrow.clockwise")
            }
            .disabled(isBusy)
            Button(String(localized: "設定を保存")) { _ = saveSelection() }
                .disabled(isBusy || !hasValidSelection)
                .accessibilityIdentifier("connectors.mapping.save")
        } header: {
            Text(provider == .reminders
                 ? String(localized: "分野とリスト")
                 : String(localized: "分野とプロジェクト"))
        } footer: {
            Text(String(localized: "分野ごとに取り込み元を選びます。同じ取り込み元を複数の分野には割り当てられません。取り込み済みのタスクの分野や集中履歴は変更しません。"))
        }
    }

    private func selectionTitle(for area: Area) -> String {
        let selectedIDs = Set(sourceAreaIDs.filter { $0.value == area.id }.keys)
        guard !selectedIDs.isEmpty else { return String(localized: "取り込まない") }
        let selected = availableSources.filter { selectedIDs.contains($0.id) }
        guard selected.count == selectedIDs.count else {
            return String(localized: "取り込み元を確認してください")
        }
        return selected.map(\.name).joined(separator: "、")
    }

    private func synchronization(_ connection: ConnectorConnection) -> some View {
        Section {
            Button {
                importTasks()
            } label: {
                Label(
                    connection.lastSyncedAt == nil
                        ? String(localized: "タスクを取り込む")
                        : String(localized: "タスクを更新"),
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy || !hasValidSelection)
            .disabled(sourceAreaIDs.isEmpty)
            .accessibilityIdentifier("connectors.import")

            if let lastSyncedAt = connection.lastSyncedAt {
                LabeledContent(String(localized: "前回の更新")) {
                    Text(lastSyncedAt, format: .dateTime.year().month().day().hour().minute())
                }
                Text(String(localized: "前回の新規取り込み：\(connection.lastImportedCount)件"))
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text(String(localized: "チェック形式のタスクは完了・未完了を相互に同期します。タイトルと期限は接続先から更新します。通信できない変更は次回の更新で再送します。"))
        }
    }

    private var disconnectSection: some View {
        Section {
            Button(String(localized: "接続を解除"), role: .destructive) {
                showsDisconnectConfirmation = true
            }
            .disabled(isBusy)
            .accessibilityIdentifier("connectors.disconnect")
            .confirmationDialog(
                String(localized: "接続を解除しますか？"),
                isPresented: $showsDisconnectConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "接続を解除"), role: .destructive) {
                    do {
                        try connectors.disconnect(provider: provider)
                    } catch {
                        connectors.errorMessage = error.localizedDescription
                    }
                }
                Button(String(localized: "キャンセル"), role: .cancel) {}
            } message: {
                Text(String(localized: "この端末の接続を解除します。取り込んだタスクと集中履歴は残ります。"))
            }
        } footer: {
            Text(String(localized: "接続とアクセスキーはこの端末で管理します。取り込んだタスクはiCloudの設定に従って同期されます。"))
        }
    }

    private func restoreSelection() {
        let activeIDs = Set(availableAreas.map(\.id))
        sourceAreaIDs = (connection?.resolvedSourceAreaIDs ?? [:]).filter { activeIDs.contains($0.value) }
    }

    @discardableResult
    private func saveSelection() -> Bool {
        guard hasValidSelection else { return false }
        do {
            try connectors.configure(provider: provider, sourceAreaIDs: sourceAreaIDs)
            connectors.errorMessage = nil
            return true
        } catch {
            connectors.errorMessage = error.localizedDescription
            return false
        }
    }

    private func importTasks() {
        guard !sourceAreaIDs.isEmpty, saveSelection() else { return }
        Task {
            await connectors.synchronize(provider: provider, modelContext: modelContext)
        }
    }
}
#endif

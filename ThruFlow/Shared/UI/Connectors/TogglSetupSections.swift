#if os(macOS) || os(iOS)
import SwiftData
import SwiftUI

struct TogglConnectorRow: View {
    @ObservedObject var store: TogglExportStore
    var body: some View {
        ConnectorProviderRow(provider: .toggl, connection: store.configuration.map {
            ConnectorConnection(provider: .toggl, account: $0.account)
        })
    }
}

struct TogglSetupSections: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var store: TogglExportStore
    let areas: [Area]
    @State private var token = ""
    @State private var workspaceID: Int64 = 0
    @State private var mappings: [String: Int64] = [:]
    @State private var enabled = true
    @State private var retryJob: TogglExportJob?
    @State private var showsDisconnect = false

    private var projects: [TogglProject] { store.projects.filter { $0.workspace_id == workspaceID } }
    private var activeAreas: [Area] { areas.filter { !$0.isArchived } }

    var body: some View {
        Group {
            Section {
                TogglConnectorRow(store: store)
                Text(String(localized: "Toggl TrackのAPIトークンは、この端末のKeychainに保存されます。"))
                    .font(.subheadline).foregroundStyle(.secondary)
                SecureField(String(localized: "APIトークン"), text: $token)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("connectors.toggl.token")
                Link(String(localized: "APIトークンを取得"), destination: URL(string: "https://track.toggl.com/profile")!)
                Button(store.configuration == nil ? String(localized: "接続") : String(localized: "再接続")) {
                    Task {
                        await store.connect(token: token)
                        if store.errorMessage == nil { token = ""; restore() }
                    }
                }
                .disabled(store.isBusy || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("connectors.toggl.connect")
            }

            if let configuration = store.configuration {
                Section {
                    Picker(String(localized: "ワークスペース"), selection: Binding(
                        get: { workspaceID }, set: { workspaceID = $0; mappings = [:] }
                    )) {
                        Text(String(localized: "選択")).tag(Int64(0))
                        ForEach(store.workspaces) { Text($0.name).tag($0.id) }
                    }
                    ConnectorMappingColumnHeaders(destination: String(localized: "プロジェクト"))
                    ForEach(activeAreas) { area in
                        ConnectorAreaMappingRow(area: area) {
                            Picker(area.name, selection: Binding(
                                get: { mappings[area.id.uuidString] ?? 0 },
                                set: { if $0 == 0 { mappings.removeValue(forKey: area.id.uuidString) } else { mappings[area.id.uuidString] = $0 } }
                            )) {
                                Text(String(localized: "送信しない")).tag(Int64(0))
                                ForEach(projects) { Text($0.name).tag($0.id) }
                            }
                            .labelsHidden()
                            .disabled(store.isBusy)
                        }
                    }
                    Toggle(String(localized: "集中時間を自動送信"), isOn: $enabled)
                    Button(String(localized: "設定を保存")) {
                        do {
                            let activeIDs = Set(activeAreas.map { $0.id.uuidString })
                            try store.configure(workspaceID: workspaceID, areaProjects: mappings.filter { activeIDs.contains($0.key) }, enabled: enabled)
                            Task { await store.synchronize(modelContext: modelContext) }
                        } catch { store.errorMessage = error.localizedDescription }
                    }
                    .disabled(store.isBusy || workspaceID == 0 || mappings.isEmpty)
                    .accessibilityIdentifier("connectors.toggl.save")
                } header: {
                    Text(String(localized: "分野とプロジェクト"))
                } footer: {
                    Text(String(localized: "有効化後にこの端末で開始したフローを送信します。休憩・過去の記録・他の端末で開始したフローは含みません。"))
                }

                Section {
                    Text(configuration.isEnabled ? String(localized: "自動送信は有効です") : String(localized: "自動送信は停止中です"))
                    Text(String(localized: "送信待ち：\(store.pendingJobs.count)件"))
                    if let date = configuration.lastSyncedAt {
                        LabeledContent(String(localized: "最終送信"), value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button(String(localized: "今すぐ送信")) {
                        Task { await store.synchronize(modelContext: modelContext) }
                    }
                    .disabled(store.isBusy || !configuration.isEnabled)
                    ForEach(store.pendingJobs.filter(\.uncertain)) { job in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(job.payload.description).font(.headline)
                            Text(String(localized: "送信結果の確認待ち"))
                                .font(.caption).foregroundStyle(.secondary)
                            Button(String(localized: "記録がない場合に再送…")) { retryJob = job }
                                .disabled(store.isBusy)
                        }
                    }
                    Link(String(localized: "Toggl Trackで確認"), destination: URL(string: "https://track.toggl.com/timer")!)
                } footer: {
                    Text(String(localized: "送信済みの記録は再送しません。ThruFlowでの後からの編集・削除はTogglに反映されません。"))
                }

                Section {
                    Button(String(localized: "接続を解除"), role: .destructive) { showsDisconnect = true }
                        .disabled(store.isBusy)
                }
            }

            if store.isBusy { Section { ProgressView().accessibilityLabel(String(localized: "接続を更新しています…")) } }
            if let message = store.errorMessage {
                Section { Text(message).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            }
        }
        .task {
            restore()
            if store.configuration != nil { await store.loadOptions() }
        }
        .confirmationDialog(String(localized: "接続を解除しますか？"), isPresented: $showsDisconnect) {
            Button(String(localized: "接続を解除"), role: .destructive) {
                do { try store.disconnect(); token = "" }
                catch { store.errorMessage = error.localizedDescription }
            }
        } message: {
            Text(String(localized: "ThruFlowとTogglの記録は残ります。自動送信を停止します。"))
        }
        .confirmationDialog(String(localized: "同じ記録がTogglにないことを確認しましたか？"), isPresented: Binding(
            get: { retryJob != nil }, set: { if !$0 { retryJob = nil } }
        )) {
            if let job = retryJob {
                Button(String(localized: "再送を許可")) {
                    do { try store.allowRetry(jobID: job.id); Task { await store.synchronize(modelContext: modelContext) } }
                    catch { store.errorMessage = error.localizedDescription }
                    retryJob = nil
                }
            }
        } message: {
            Text(String(localized: "すでに送信されている場合は重複します。まずTogglの記録を確認してください。"))
        }
    }

    private func restore() {
        workspaceID = store.configuration?.workspaceID ?? 0
        mappings = store.configuration?.areaProjects ?? [:]
        enabled = store.configuration?.isEnabled ?? true
    }
}
#endif

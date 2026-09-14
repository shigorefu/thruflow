import Foundation

nonisolated struct TogglWorkspace: Codable, Equatable, Identifiable, Sendable {
    let id: Int64
    let name: String
}

nonisolated struct TogglProject: Codable, Equatable, Identifiable, Sendable {
    let id: Int64
    let workspace_id: Int64
    let name: String
    var active: Bool = true
    var can_track_time: Bool? = nil
}

nonisolated struct TogglTimePayload: Codable, Equatable, Sendable {
    let workspace_id: Int64
    let project_id: Int64
    let description: String
    let start: String
    let duration: Int
    var created_with: String = "ThruFlow"
    var tags: [String] = ["ThruFlow"]
}

nonisolated struct TogglRemoteEntry: Decodable, Sendable {
    let id: Int64
    let workspace_id: Int64
    let project_id: Int64?
    let description: String?
    let start: String
    let duration: Int
    let tags: [String]?

    func matches(_ payload: TogglTimePayload) -> Bool {
        workspace_id == payload.workspace_id && project_id == payload.project_id &&
        description == payload.description && duration == payload.duration &&
        tags?.contains("ThruFlow") == true &&
        Self.date(start) != nil && Self.date(start) == Self.date(payload.start)
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
}

nonisolated struct TogglExportJob: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let accountID: String
    let deviceID: String
    let sessionID: UUID
    let payload: TogglTimePayload
    var isCancelled = false
    var uncertain = false
    var remoteID: Int64?
}

nonisolated struct TogglConfiguration: Codable, Equatable, Sendable {
    let account: ConnectorAccount
    var workspaceID: Int64?
    var areaProjects: [String: Int64] = [:]
    var enabledAt: Date?
    var isEnabled = false
    var lastSyncedAt: Date?
}

nonisolated struct TogglExportState: Codable, Sendable {
    var version = 1
    var configuration: TogglConfiguration?
    var jobs: [TogglExportJob] = []
}

nonisolated enum TogglError: Error, LocalizedError {
    case credentials, configuration, storage, uncertain, ambiguous
    case rejected(Int)
    case rateLimited(TimeInterval)
    var errorDescription: String? {
        switch self {
        case .credentials: String(localized: "Toggl TrackのAPIトークンを確認してください。")
        case .configuration: String(localized: "ワークスペースと分野ごとのプロジェクトを選択してください。")
        case .storage: String(localized: "送信待ちの記録を保存または読み込めませんでした。")
        case .uncertain: String(localized: "送信結果を確認できません。Togglの記録を確認してください。")
        case .ambiguous: String(localized: "Togglに一致する記録が複数あります。自動再送を停止しました。")
        case .rejected: String(localized: "Togglがリクエストを受け付けませんでした。アクセス権とプロジェクトを確認してください。")
        case .rateLimited: String(localized: "Togglの利用制限に達しました。時間をおいて再試行してください。")
        }
    }
}

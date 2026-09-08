import Foundation

nonisolated enum ConnectorProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case reminders
    case todoist

    var id: String { rawValue }
}

nonisolated struct ConnectorAccount: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
}

nonisolated struct ConnectorSource: Codable, Equatable, Identifiable, Sendable {
    /// Source identifiers are provider-local. EventKit list identifiers are device-local.
    let id: String
    let name: String
}

nonisolated struct ConnectorTask: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let sourceID: String
    let title: String
    var notes: String? = nil
    var dueDate: Date? = nil
    var isCompleted: Bool = false
    var completedAt: Date? = nil
    var url: URL? = nil
}

/// Reads and explicitly requested completion changes; never deletes source tasks.
@MainActor
protocol ConnectorClient {
    func account() async throws -> ConnectorAccount
    func sources() async throws -> [ConnectorSource]
    func tasks(sourceIDs: Set<String>) async throws -> [ConnectorTask]
    func completedTasks(sourceIDs: Set<String>, since: Date, until: Date) async throws -> [ConnectorTask]
    func setCompletion(taskID: String, sourceIDs: Set<String>, change: ConnectorCompletionChange) async throws
}

extension ConnectorClient {
    func completedTasks(sourceIDs: Set<String>, since: Date, until: Date) async throws -> [ConnectorTask] { [] }
}

nonisolated enum ConnectorProviderError: Error, LocalizedError, Equatable, Sendable {
    case accessDenied
    case invalidCredential
    case invalidResponse
    case sourceUnavailable
    case ambiguousTaskIdentity
    case rateLimited
    case serviceUnavailable
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            String(localized: "アクセスが許可されていません。システム設定でアクセスを確認してください。")
        case .invalidCredential:
            String(localized: "接続の認証に失敗しました。もう一度接続してください。")
        case .invalidResponse:
            String(localized: "接続先のデータを読み取れませんでした。時間をおいて再試行してください。")
        case .sourceUnavailable:
            String(localized: "選択したリストが見つかりません。リストを選び直してください。")
        case .ambiguousTaskIdentity:
            String(localized: "同じ識別子のタスクが複数あります。接続先で重複した項目を確認してください。")
        case .rateLimited:
            String(localized: "接続先の利用制限に達しました。時間をおいて再試行してください。")
        case .serviceUnavailable:
            String(localized: "接続先を利用できません。時間をおいて再試行してください。")
        case .networkUnavailable:
            String(localized: "接続先に通信できません。インターネット接続を確認してください。")
        }
    }
}

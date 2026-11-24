import SwiftUI

struct CloudSyncSettingsSection: View {
    @ObservedObject private var issueCenter = PersistenceIssueCenter.shared

    var body: some View {
        Section(String(localized: "iCloud同期")) {
            Label(statusText, systemImage: symbolName)
                .foregroundStyle(statusColor)

            if showsRecoveryHelp {
                Text(String(localized: "iCloud Driveと、ThruFlowのiCloud利用設定を確認してから、アプリを開き直してください。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        switch issueCenter.cloudSyncState {
        case .localOnly:
            String(localized: "このビルドでは端末内にのみ保存されます")
        case .checking:
            String(localized: "iCloudを確認しています…")
        case .available:
            String(localized: "iCloudを利用できます")
        case .syncing:
            String(localized: "同期しています…")
        case .synced:
            String(localized: "同期済み")
        case .unavailable:
            String(localized: "iCloudを利用できません")
        case .failed:
            String(localized: "iCloudと同期できませんでした")
        }
    }

    private var symbolName: String {
        switch issueCenter.cloudSyncState {
        case .localOnly: "externaldrive"
        case .checking, .syncing: "arrow.triangle.2.circlepath.icloud"
        case .available, .synced: "checkmark.icloud"
        case .unavailable, .failed: "exclamationmark.icloud"
        }
    }

    private var statusColor: Color {
        switch issueCenter.cloudSyncState {
        case .unavailable, .failed: .red
        default: .secondary
        }
    }

    private var showsRecoveryHelp: Bool {
        switch issueCenter.cloudSyncState {
        case .unavailable, .failed: true
        default: false
        }
    }
}

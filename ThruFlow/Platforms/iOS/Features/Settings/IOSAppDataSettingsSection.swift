#if os(iOS)
import SwiftUI

struct IOSAppDataSettingsSection: View {
    let isResetting: Bool
    let hasActiveFlow: Bool
    let resetStatus: IOSAppResetStatus?
    let onResetRequested: () -> Void

    var body: some View {
        Section(String(localized: "データ")) {
            Button(role: .destructive) {
                onResetRequested()
            } label: {
                Label(String(localized: "アプリのデータをリセット"), systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("settings.reset-app-data")
            .disabled(isResetting || hasActiveFlow)

            if isResetting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "アプリのデータをリセットしています…"))
                }
                .foregroundStyle(.secondary)
            } else if hasActiveFlow {
                Label(
                    String(localized: "リセットする前に、現在のFlowを終了してください。"),
                    systemImage: "timer"
                )
                .foregroundStyle(.secondary)
            } else if let resetStatus {
                Label(resetStatus.message, systemImage: resetStatus.symbolName)
                    .foregroundStyle(resetStatus.isError ? Color.red : Color.secondary)
            }

            Text(String(localized: "タスク、分野、集中履歴、メモがすべて削除されます。設定は残ります。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

enum IOSAppResetStatus {
    case activeFlow
    case failure

    var message: String {
        switch self {
        case .activeFlow: String(localized: "リセットする前に、現在のFlowを終了してください。")
        case .failure: String(localized: "アプリのデータをリセットできませんでした")
        }
    }

    var symbolName: String {
        switch self {
        case .activeFlow: "timer"
        case .failure: "exclamationmark.triangle"
        }
    }

    var isError: Bool {
        self == .failure
    }
}
#endif

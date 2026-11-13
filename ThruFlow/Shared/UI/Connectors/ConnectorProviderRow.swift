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
                Text(provider.connectorTitle)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
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

#endif

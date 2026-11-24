import SwiftUI

struct NotificationSettingsSection: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var delivery = NotificationDeliveryRuntime.shared

    var body: some View {
        Section(String(localized: "通知")) {
            Toggle(
                String(localized: "ThruFlowの通知サーバーを使用"),
                isOn: Binding(
                    get: { settings.serverNotificationsEnabled },
                    set: { enabled in
                        settings.serverNotificationsEnabled = enabled
                        if NotificationDeliveryRuntime.isEnabled {
                            delivery.setRemoteEnabled(enabled)
                        }
                    }
                )
            )
            .accessibilityIdentifier("settings.server-notifications")

            Text(String(localized: "オフにすると、この端末の通知は端末内で予約します。iCloud同期とコネクタの設定は変わりません。"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !settings.serverNotificationsEnabled {
                Text(String(localized: "サーバーで予約済みの通知は、オフライン中や送信済みの場合、届くことがあります。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if delivery.revocationUnconfirmed {
                Label(
                    String(localized: "サーバー上の通知予約の削除を確認できません"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

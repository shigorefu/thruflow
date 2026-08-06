import SwiftUI

struct FeedbackSettingsSection: View {
    var body: some View {
        Section {
            Link(destination: SupportLinks.feedbackURL) {
                Label(
                    String(localized: "フィードバックを送る"),
                    systemImage: "bubble.left.and.bubble.right"
                )
            }

            Label(
                String(localized: "TestFlight版では、スクリーンショットまたはTestFlightアプリから端末情報付きのフィードバックを送信できます。"),
                systemImage: "testtube.2"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        } header: {
            Text(String(localized: "フィードバック"))
        } footer: {
            Text(String(localized: "GitHub Issuesへの投稿は公開されます。個人情報や公開したくないタスク名・メモを含めないでください。"))
        }
    }
}

import SwiftUI

struct SupportSettingsSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            if let reviewURL = SupportLinks.appStoreReviewURL {
                Button {
                    openURL(reviewURL)
                } label: {
                    Label(String(localized: "App Storeで評価"), systemImage: "star.bubble")
                }
            }

            Button {
                openURL(SupportLinks.projectURL)
            } label: {
                Label(String(localized: "GitHubで開発に参加"), systemImage: "chevron.left.forwardslash.chevron.right")
            }
        } header: {
            Text(String(localized: "ThruFlowを応援"))
        }
    }
}

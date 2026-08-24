import SwiftUI

struct SupportSettingsSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Button {
                openURL(SupportLinks.supportURL)
            } label: {
                Label(String(localized: "お問い合わせ"), systemImage: "bubble.left.and.bubble.right")
            }

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
                Label(String(localized: "ソースコード"), systemImage: "chevron.left.forwardslash.chevron.right")
            }
        } header: {
            Text(String(localized: "サポート"))
        }
    }
}

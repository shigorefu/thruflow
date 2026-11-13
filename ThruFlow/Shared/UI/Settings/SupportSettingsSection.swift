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

/// Shared by the Mac and iPhone language settings.
struct ChineseTranslationNotice: View {
    let languageCode: String

    private var isChineseSelected: Bool {
        let selectedCode = languageCode == AppSettings.systemLanguageCode
            ? Bundle.preferredLocalizations(
                from: Bundle.main.localizations,
                forPreferences: Locale.preferredLanguages
            ).first ?? "ja"
            : languageCode
        return selectedCode == "zh" || selectedCode.hasPrefix("zh-")
    }

    var body: some View {
        if isChineseSelected {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "中国語の翻訳にはAIを使用しているため、不正確な表現が含まれる場合があります。お気づきの点はサポートまでお知らせください。"))
                    .foregroundStyle(.secondary)
                Link(String(localized: "お問い合わせ"), destination: SupportLinks.supportURL)
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

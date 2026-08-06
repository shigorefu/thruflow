import SwiftUI

struct SupportSettingsSection: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var purchaseStore: SupportPurchaseStore

    @State private var message: SupportMessage?

    var body: some View {
        Section {
            Text(String(localized: "ThruFlowが役に立っているなら、これからの開発を応援していただけるとうれしいです。"))
                .font(.callout)
                .foregroundStyle(.secondary)

            if let reviewURL = SupportLinks.appStoreReviewURL {
                Button {
                    openURL(reviewURL)
                } label: {
                    Label(String(localized: "App Storeで評価"), systemImage: "star.bubble")
                }
            }

            Button {
                openURL(SupportLinks.githubURL)
            } label: {
                Label(String(localized: "GitHubで開発に参加"), systemImage: "chevron.left.forwardslash.chevron.right")
            }

            tipButton(.coffee)
            tipButton(.ramen)
        } header: {
            Text(String(localized: "ThruFlowを応援"))
        } footer: {
            Text(String(localized: "コーヒー一杯、あるいはラーメン一杯で開発を応援できます。購入しても機能は変わりません。"))
        }
        .task {
            await purchaseStore.loadProducts()
        }
        .alert(item: $message) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.body),
                dismissButton: .default(Text(String(localized: "OK")))
            )
        }
    }

    private func tipButton(_ tip: SupportTip) -> some View {
        Button {
            Task {
                let outcome = await purchaseStore.purchase(tip)
                switch outcome {
                case .purchased:
                    message = .thankYou
                case .pending:
                    message = .pending
                case .unavailable, .failed:
                    message = .unavailable
                case .cancelled:
                    break
                }
            }
        } label: {
            HStack(spacing: 12) {
                Label(tip.title, systemImage: tip.systemImage)
                Spacer()
                if purchaseStore.purchasingTip == tip {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(purchaseStore.displayPrice(for: tip))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .disabled(purchaseStore.purchasingTip != nil || (purchaseStore.isLoading && purchaseStore.products.isEmpty))
        .accessibilityLabel("\(tip.title), \(purchaseStore.displayPrice(for: tip))")
    }
}

private extension SupportTip {
    var title: String {
        switch self {
        case .coffee: String(localized: "コーヒーを贈る")
        case .ramen: String(localized: "ラーメンを贈る")
        }
    }

    var systemImage: String {
        switch self {
        case .coffee: "cup.and.saucer.fill"
        case .ramen: "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

private enum SupportLinks {
    static let githubURL = URL(string: "https://github.com/shigorefu/thruflow")!

    static var appStoreReviewURL: URL? {
        guard let appStoreID = Bundle.main.object(forInfoDictionaryKey: "ThruFlowAppStoreID") as? String,
              !appStoreID.isEmpty,
              !appStoreID.contains("$(") else {
            return nil
        }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}

private struct SupportMessage: Identifiable {
    enum Kind {
        case thankYou
        case pending
        case unavailable
    }

    let kind: Kind
    var id: Kind { kind }

    var title: String {
        switch kind {
        case .thankYou: String(localized: "ありがとうございます！")
        case .pending: String(localized: "購入を確認しています")
        case .unavailable: String(localized: "購入できませんでした")
        }
    }

    var body: String {
        switch kind {
        case .thankYou:
            String(localized: "ThruFlowの開発を応援していただき、ありがとうございます。")
        case .pending:
            String(localized: "承認が完了すると購入が自動的に処理されます。")
        case .unavailable:
            String(localized: "時間をおいてから、もう一度お試しください。")
        }
    }

    static let thankYou = SupportMessage(kind: .thankYou)
    static let pending = SupportMessage(kind: .pending)
    static let unavailable = SupportMessage(kind: .unavailable)
}

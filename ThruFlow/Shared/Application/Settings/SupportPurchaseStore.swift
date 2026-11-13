import Combine
import Foundation
import StoreKit

enum SupportTip: String, CaseIterable, Identifiable {
    case coffee = "com.shigorefu.thruflow.tip.coffee"
    case ramen = "com.shigorefu.thruflow.tip.ramen"

    var id: String { rawValue }

    var fallbackPrice: String {
        switch self {
        case .coffee: "¥100"
        case .ramen: "¥500"
        }
    }
}

enum SupportPurchaseOutcome: Equatable {
    case purchased(SupportTip)
    case cancelled
    case pending
    case unavailable
    case failed
}

@MainActor
final class SupportPurchaseStore: ObservableObject {
    @Published private(set) var products: [SupportTip: Product] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingTip: SupportTip?

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task(priority: .background) {
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case let .verified(transaction) = result,
                      SupportTip(rawValue: transaction.productID) != nil else {
                    continue
                }
                await transaction.finish()
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProducts() async {
        guard products.count != SupportTip.allCases.count, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedProducts = try await Product.products(for: SupportTip.allCases.map(\.rawValue))
            products = Dictionary(uniqueKeysWithValues: loadedProducts.compactMap { product in
                guard let tip = SupportTip(rawValue: product.id) else { return nil }
                return (tip, product)
            })
        } catch {
            products = [:]
        }
    }

    func displayPrice(for tip: SupportTip) -> String {
        products[tip]?.displayPrice ?? tip.fallbackPrice
    }

    func purchase(_ tip: SupportTip) async -> SupportPurchaseOutcome {
        if products[tip] == nil {
            await loadProducts()
        }
        guard let product = products[tip], purchasingTip == nil else {
            return .unavailable
        }

        purchasingTip = tip
        defer { purchasingTip = nil }

        do {
            switch try await product.purchase() {
            case let .success(result):
                guard case let .verified(transaction) = result else { return .failed }
                await transaction.finish()
                return .purchased(tip)
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }
}

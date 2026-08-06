import Foundation
import Testing

struct StoreKitConfigurationTests {
    @Test func supportTipsAreConsumableAndUseStableIdentifiers() throws {
        let data = try Data(contentsOf: configurationURL)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try #require(root["products"] as? [[String: Any]])
        let indexed = Dictionary(uniqueKeysWithValues: products.compactMap { product -> (String, [String: Any])? in
            guard let identifier = product["productID"] as? String else { return nil }
            return (identifier, product)
        })

        #expect(Set(indexed.keys) == [
            "com.shigorefu.thruflow.tip.coffee",
            "com.shigorefu.thruflow.tip.ramen"
        ])
        #expect(indexed.values.allSatisfy { $0["type"] as? String == "Consumable" })
        #expect(indexed["com.shigorefu.thruflow.tip.coffee"]?["displayPrice"] as? String == "100")
        #expect(indexed["com.shigorefu.thruflow.tip.ramen"]?["displayPrice"] as? String == "500")

        for product in indexed.values {
            let localizations = try #require(product["localizations"] as? [[String: Any]])
            let locales = Set(localizations.compactMap { $0["locale"] as? String })
            #expect(locales == ["en_US", "ja_JP", "ru_RU"])
        }
    }

    private var configurationURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "ThruFlow/Configuration.storekit")
    }
}

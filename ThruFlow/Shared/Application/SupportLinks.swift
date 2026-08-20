import Foundation

enum SupportLinks {
    static let projectURL = URL(string: "https://github.com/shigorefu/thruflow")!

    static var appStoreReviewURL: URL? {
        guard let appStoreID = Bundle.main.object(forInfoDictionaryKey: "ThruFlowAppStoreID") as? String,
              !appStoreID.isEmpty,
              !appStoreID.contains("$(") else {
            return nil
        }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}

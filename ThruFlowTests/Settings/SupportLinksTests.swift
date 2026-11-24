import Foundation
import Testing
@testable import ThruFlow

struct SupportLinksTests {
    @Test func reviewLinkUsesTheConfiguredAppStoreProduct() {
        #expect(
            SupportLinks.appStoreReviewURL?.absoluteString ==
                "https://apps.apple.com/app/id6798609191?action=write-review"
        )
    }
}

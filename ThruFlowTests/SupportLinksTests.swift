import Foundation
import Testing
@testable import ThruFlow

struct SupportLinksTests {
    @Test func projectLinkUsesThePublicRepository() {
        #expect(SupportLinks.projectURL.absoluteString == "https://github.com/shigorefu/thruflow")
    }
}

import Foundation
import Testing
@testable import ThruFlow

struct SupportLinksTests {
    @Test func supportLinkUsesThePublicSupportPage() {
        #expect(SupportLinks.supportURL.absoluteString == "https://thruflow.shigorefu.com/support")
    }

    @Test func projectLinkUsesThePublicRepository() {
        #expect(SupportLinks.projectURL.absoluteString == "https://github.com/shigorefu/thruflow")
    }
}

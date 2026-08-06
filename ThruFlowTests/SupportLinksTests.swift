import Foundation
import Testing
@testable import ThruFlow

struct SupportLinksTests {
    @Test func projectLinkUsesThePublicRepository() {
        #expect(SupportLinks.projectURL.absoluteString == "https://github.com/shigorefu/thruflow")
    }

    @Test func feedbackLinkOpensTheIssueTemplateChooser() {
        #expect(
            SupportLinks.feedbackURL.absoluteString ==
                "https://github.com/shigorefu/thruflow/issues/new/choose"
        )
    }
}

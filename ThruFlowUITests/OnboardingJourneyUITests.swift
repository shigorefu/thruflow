import XCTest

final class OnboardingJourneyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNewUserCanWalkThroughEveryOnboardingSection() throws {
        let app = launchPreview()

        assertStep(0, in: app)
        capture(app, name: "Onboarding 1 Welcome")

        let pages = ["Flow", "Directions", "Tasks", "History", "Statistics", "Workflow"]
        for (index, pageName) in pages.enumerated() {
            nextButton(step: index, in: app).tap()
            assertStep(index + 1, in: app)
            capture(app, name: "Onboarding \(index + 2) \(pageName)")
        }

        XCTAssertTrue(app.buttons["onboarding.finish.step.6"].exists)
        app.buttons["onboarding.finish.step.6"].tap()
        XCTAssertFalse(element("onboarding.journey", in: app).waitForExistence(timeout: 1))
    }

    @MainActor
    func testBackAndSkipControlsRemainAvailable() throws {
        let app = launchPreview()

        XCTAssertTrue(nextButton(step: 0, in: app).waitForExistence(timeout: 5))
        nextButton(step: 0, in: app).tap()
        assertStep(1, in: app)
        XCTAssertTrue(app.buttons["onboarding.back.step.1"].exists)
        app.buttons["onboarding.back.step.1"].tap()
        assertStep(0, in: app)

        app.buttons["onboarding.skip"].tap()
        XCTAssertFalse(element("onboarding.journey", in: app).waitForExistence(timeout: 1))
    }

    @MainActor
    private func launchPreview() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--onboarding-preview"]
        app.launch()

#if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 2) {
            app.activate()
            app.typeKey("n", modifierFlags: .command)
            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 3))
        }
#endif
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func assertStep(
        _ step: Int,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let journey = element("onboarding.journey", in: app)
        XCTAssertTrue(journey.waitForExistence(timeout: 5), file: file, line: line)
        let expectedIdentifier = step == 6
            ? "onboarding.finish.step.6"
            : "onboarding.next.step.\(step)"
        let stepControl = app.buttons[expectedIdentifier]
        XCTAssertTrue(stepControl.waitForExistence(timeout: 2), file: file, line: line)
        XCTAssertEqual(stepControl.identifier, expectedIdentifier, file: file, line: line)
    }

    private func nextButton(step: Int, in app: XCUIApplication) -> XCUIElement {
        app.buttons["onboarding.next.step.\(step)"]
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

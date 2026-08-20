import XCTest

final class OnboardingJourneyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTourWalksThroughAllEightSteps() throws {
        let app = launchPreview(experience: "tour")
        defer { terminate(app) }

        assertStep(0, in: app)
        capture(app, name: "Onboarding 1 Welcome")

        nextButton(step: 0, in: app).tap()
        assertStep(1, in: app)
        app.buttons["onboarding.back.step.1"].tap()
        assertStep(0, in: app)
        nextButton(step: 0, in: app).tap()

        let pages = [
            "Areas",
            "Tasks",
            "Flow",
            "Demo",
            "History",
            "Statistics",
            "Workflow",
        ]
        for (offset, pageName) in pages.enumerated() {
            let step = offset + 1
            assertStep(step, in: app)
            capture(app, name: "Onboarding \(step + 1) \(pageName)")

            guard step < 7 else { continue }
            advanceTour(from: step, in: app).tap()
        }

        XCTAssertTrue(app.buttons["onboarding.finish.step.7"].exists)
        app.buttons["onboarding.finish.step.7"].tap()
        XCTAssertFalse(element("onboarding.journey", in: app).waitForExistence(timeout: 1))
    }

    @MainActor
    func testGuidedJourneyCreatesAreaAndTaskThenRunsEphemeralDemo() throws {
        let app = launchPreview(experience: "guided")
        defer { terminate(app) }

        assertStep(0, in: app)
        nextButton(step: 0, in: app).tap()
        assertStep(1, in: app)

        let createArea = app.buttons["onboarding.create-area.step.1"]
        XCTAssertTrue(createArea.waitForExistence(timeout: 2))
        createArea.tap()

        let saveArea = app.buttons["direction.editor.save"]
        XCTAssertTrue(saveArea.waitForExistence(timeout: 3))
        XCTAssertTrue(saveArea.isEnabled)
        saveArea.tap()
        assertStep(2, in: app)

        let createTask = app.buttons["onboarding.create-task.step.2"]
        XCTAssertTrue(createTask.waitForExistence(timeout: 2))
        createTask.tap()

        let saveTask = app.buttons["task.composer.submit"]
        XCTAssertTrue(saveTask.waitForExistence(timeout: 3))
        XCTAssertTrue(saveTask.isEnabled)
        saveTask.tap()
        assertStep(3, in: app)

        nextButton(step: 3, in: app).tap()
        assertStep(4, in: app)

        let startDemo = app.buttons["onboarding.demo.start.step.4"]
        XCTAssertTrue(startDemo.waitForExistence(timeout: 2))
        startDemo.tap()

        let continueAfterDemo = nextButton(step: 4, in: app)
        XCTAssertTrue(continueAfterDemo.waitForExistence(timeout: 12))
        continueAfterDemo.tap()
        assertStep(5, in: app)

        app.buttons["onboarding.skip"].tap()
        XCTAssertFalse(element("onboarding.journey", in: app).waitForExistence(timeout: 1))
    }

    @MainActor
    private func launchPreview(experience: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--onboarding-preview",
            "--onboarding-experience=\(experience)",
        ]
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
        let card = element("onboarding.card.step.\(step)", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 2), file: file, line: line)
    }

    private func nextButton(step: Int, in app: XCUIApplication) -> XCUIElement {
        app.buttons["onboarding.next.step.\(step)"]
    }

    private func advanceTour(from step: Int, in app: XCUIApplication) -> XCUIElement {
        if step == 4 {
            return app.buttons["onboarding.demo.skip.step.4"]
        }
        return nextButton(step: step, in: app)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func terminate(_ app: XCUIApplication) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 5)
    }
}

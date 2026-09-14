import XCTest

final class ConnectorNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testConnectorsOpenAboveSettingsAndExplainTodoistSignIn() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--onboarding-preview",
            "--onboarding-experience=tour",
        ]
        app.launch()
        defer {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 5)
        }

#if os(macOS)
        if !app.windows.firstMatch.waitForExistence(timeout: 2) {
            app.activate()
            app.typeKey("n", modifierFlags: .command)
            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 3))
        }
#endif
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()

        let connectors = app.buttons["connectors.open"]
#if os(iOS)
        if !connectors.exists {
            let more = app.buttons["flow.more"]
            XCTAssertTrue(more.waitForExistence(timeout: 5))
            more.tap()
        }
#endif
        XCTAssertTrue(connectors.waitForExistence(timeout: 5))
#if os(macOS)
        let settings = app.buttons["settings.open"]
        XCTAssertTrue(settings.exists)
        XCTAssertLessThan(connectors.frame.midY, settings.frame.midY)
#endif
        connectors.tap()

        let reminders = app.descendants(matching: .any)["connectors.provider.reminders"].firstMatch
        let todoist = app.descendants(matching: .any)["connectors.provider.todoist"].firstMatch
        XCTAssertTrue(reminders.waitForExistence(timeout: 3))
        XCTAssertTrue(todoist.exists)
        todoist.tap()

        let authorize = app.buttons["connectors.authorize.todoist"]
        XCTAssertTrue(authorize.waitForExistence(timeout: 3))
        XCTAssertTrue(authorize.isEnabled)
        XCTAssertTrue(app.staticTexts["connectors.todoist.explanation"].exists)
        XCTAssertEqual(app.secureTextFields.count, 0)
    }
}

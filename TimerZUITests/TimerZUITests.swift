import XCTest

@MainActor
final class TimerZUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Timers tab

    func testTimersTabShowsDefaultPresets() {
        XCTAssertTrue(app.buttons["5 min"].exists)
        XCTAssertTrue(app.buttons["10 min"].exists)
        XCTAssertTrue(app.buttons["15 min"].exists)
        XCTAssertTrue(app.buttons["25 min"].exists)
    }

    func testTappingPresetOpensTimerSession() {
        app.buttons["5 min"].tap()
        XCTAssertTrue(app.staticTexts["5 min session"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Complete"].exists)
    }

    func testCancelDismissesWithoutSaving() {
        app.buttons["5 min"].tap()
        XCTAssertTrue(app.staticTexts["5 min session"].waitForExistence(timeout: 2))

        // Dismiss via cancel
        app.buttons["xmark.circle.fill"].tap()
        app.alerts["Cancel session?"].buttons["Cancel Session"].tap()

        // Back on home screen
        XCTAssertTrue(app.buttons["5 min"].waitForExistence(timeout: 2))
    }

    // MARK: - Stats tab

    func testStatsTabEmptyState() {
        app.tabBars.buttons["Stats"].tap()
        XCTAssertTrue(app.navigationBars["Stats"].waitForExistence(timeout: 2))
    }

    // MARK: - Settings tab

    func testSettingsTabShowsPresetSection() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Timer Presets"].exists)
        XCTAssertTrue(app.staticTexts["5 min"].exists)
    }

    func testSettingsTogglesExist() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Background Notifications"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["Haptic Feedback"].exists)
        XCTAssertTrue(app.switches["Sound on Expiry"].exists)
    }
}

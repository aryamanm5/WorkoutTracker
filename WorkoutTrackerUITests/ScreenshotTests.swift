import XCTest

/// Drives the main flows and writes screenshots to /tmp for visual review.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/wt_\(name).png"))
    }

    func testCaptureScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-demoSeed", "1"]
        app.launch()

        // Workout flow with plate calculator
        app.buttons["Start Workout"].tap()
        sleep(1)
        snap(app, "01_exercise_list")
        app.buttons["Bench Press"].firstMatch.tap()
        sleep(1)
        app.buttons["Log Workout"].tap()
        sleep(1)
        snap(app, "02_logging_top")
        app.swipeUp()
        snap(app, "03_logging_mid")

        // Tracking tab: calendar + chart
        app.tabBars.buttons["Tracking"].tap()
        sleep(1)
        app.swipeUp()
        snap(app, "04_tracking_calendar")
        app.swipeUp()
        snap(app, "05_tracking_chart")

        // Body tab
        app.tabBars.buttons["Body"].tap()
        sleep(1)
        snap(app, "06_body")

        // Settings
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        snap(app, "07_settings")

        // Muscle target editor
        app.staticTexts["Pull Exercises (6)"].tap()
        sleep(1)
        app.staticTexts["Rear Delt Fly"].tap()
        sleep(1)
        snap(app, "08_muscle_editor")
    }

    func testCaptureLightMode() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-demoSeed", "1", "-appAppearance", "Light", "-initialTab", "1"]
        app.launch()
        sleep(2)
        snap(app, "10_light_tracking")
        app.swipeUp()
        snap(app, "11_light_calendar")
        app.swipeUp()
        snap(app, "12_light_chart")
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        snap(app, "13_light_settings")
    }
}

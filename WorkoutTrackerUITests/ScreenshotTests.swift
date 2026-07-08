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
        app.launchArguments += ["-demoSeed", "1", "-resetData", "1"]
        app.launch()
        sleep(2)

        // Today dashboard
        snap(app, "01_today_top")
        app.swipeUp()
        snap(app, "02_today_recovery")
        app.swipeDown()

        // Force a push focus (demo seed trains everything today, so the
        // coach may recommend rest and hide the start button otherwise).
        let switcher = app.buttons["Change focus"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
        switcher.tap()
        var pushItem = app.buttons["Push Day"].firstMatch
        if !pushItem.waitForExistence(timeout: 3) {
            switcher.tap() // menu didn't open on the first tap; try again
            pushItem = app.buttons["Push Day"].firstMatch
            _ = pushItem.waitForExistence(timeout: 3)
        }
        pushItem.tap()
        sleep(1)

        let start = app.buttons["startTraining"]
        if start.waitForExistence(timeout: 3) {
            start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            // The queue is open once its Add Exercise button exists
            _ = app.buttons["Add Exercise"].firstMatch.waitForExistence(timeout: 5)
            sleep(1)
            snap(app, "03_session_queue")

            // Open the first exercise (rows are buttons whose label contains
            // the exercise name) — this lands on the preview screen with the
            // last workout and the coach's recommendation.
            let benchRow = app.buttons.containing(
                NSPredicate(format: "label CONTAINS 'Bench Press'")
            ).firstMatch
            if benchRow.waitForExistence(timeout: 5) {
                benchRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            sleep(1)
            snap(app, "04_exercise_preview")

            // Step through to the logger (coordinate tap — plain tap() can be
            // swallowed right after the push animation)
            let startExercise = app.buttons["Start Exercise"].firstMatch
            if startExercise.waitForExistence(timeout: 3) {
                startExercise.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                _ = app.buttons["Log Set 1"].firstMatch.waitForExistence(timeout: 3)
                sleep(1)
            }
            snap(app, "05_logger_top")

            // Log a set to trigger the rest countdown
            let logSet = app.buttons["Log Set 1"].firstMatch
            if logSet.waitForExistence(timeout: 3) {
                // Plain tap() can be swallowed right after the push animation;
                // a coordinate tap on the element's center is reliable.
                logSet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            sleep(2)
            snap(app, "06_logger_rest_timer")

            app.swipeUp()
            snap(app, "07_logger_scrolled")

            // Finish the exercise and land back on the queue
            let finish = app.buttons["Finish Exercise"].firstMatch
            if finish.exists {
                finish.tap()
                sleep(1)
                snap(app, "08_queue_after_exercise")
            }

            // Session summary
            let finishSession = app.buttons["Finish Session"].firstMatch
            if finishSession.waitForExistence(timeout: 3) {
                finishSession.tap()
                sleep(1)
                snap(app, "09_session_summary")
                app.buttons["Done"].firstMatch.tap()
                sleep(1)
            }
        }

        // Insights
        app.tabBars.buttons["Insights"].tap()
        sleep(1)
        snap(app, "10_insights_top")
        app.swipeUp()
        snap(app, "11_insights_calendar")
        app.swipeUp()
        snap(app, "12_insights_trend")

        // Body
        app.tabBars.buttons["Body"].tap()
        sleep(1)
        snap(app, "13_body")

        // Settings
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        snap(app, "14_settings")

        // Muscle target editor (below the privacy card — scroll to it)
        app.swipeUp()
        app.staticTexts["Manage Exercises"].tap()
        sleep(1)
        snap(app, "15_manage_exercises")
        app.staticTexts["Rear Delt Fly"].firstMatch.tap()
        sleep(1)
        snap(app, "16_muscle_editor")
    }

    func testCaptureLightMode() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-demoSeed", "1", "-resetData", "1", "-appAppearance", "Light", "-initialTab", "1"]
        app.launch()
        sleep(2)
        snap(app, "20_light_insights")
        app.swipeUp()
        snap(app, "21_light_calendar")
        app.tabBars.buttons["Today"].tap()
        sleep(1)
        snap(app, "22_light_today")
        app.tabBars.buttons["Body"].tap()
        sleep(1)
        snap(app, "23_light_body")
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        snap(app, "24_light_settings")
    }
}

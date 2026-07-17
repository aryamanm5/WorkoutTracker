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

            // Open an exercise not yet trained today (rows already logged
            // today open the session editor instead of the preview).
            let dipsRow = app.buttons.containing(
                NSPredicate(format: "label CONTAINS 'Tricep Dips'")
            ).firstMatch
            if dipsRow.waitForExistence(timeout: 5) {
                dipsRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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

    /// Drives the new flows: a session that stays on its day after finishing
    /// an exercise, editing a completed exercise mid-session, and logging &
    /// editing a body measurement.
    func testNewFeatureFlows() throws {
        let app = XCUIApplication()
        // Past-only seed: today stays untrained, so the focus card shows the
        // day name and the whole queue starts fresh.
        app.launchArguments += ["-demoSeed", "1", "-demoSeedPastOnly", "1", "-resetData", "1"]
        app.launch()
        sleep(2)

        // Force a push focus so the day is known. The menu tap occasionally
        // doesn't land, so verify the card actually says "Push Day" and retry.
        let switcher = app.buttons["Change focus"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))
        var attempts = 0
        while !app.staticTexts["Push Day"].firstMatch.exists && attempts < 4 {
            switcher.tap()
            let pushItem = app.buttons["Push Day"].firstMatch
            if pushItem.waitForExistence(timeout: 3) {
                pushItem.tap()
            }
            sleep(1)
            attempts += 1
        }
        XCTAssertTrue(app.staticTexts["Push Day"].firstMatch.waitForExistence(timeout: 2))

        let start = app.buttons["startTraining"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Push · The Gym"].waitForExistence(timeout: 5))

        // Nothing is trained today with the past-only seed, so Bench Press
        // opens the preview → logger flow with its history and coach advice.
        let benchRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Bench Press'")
        ).firstMatch
        XCTAssertTrue(benchRow.waitForExistence(timeout: 5))
        benchRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let startExercise = app.buttons["Start Exercise"].firstMatch
        XCTAssertTrue(startExercise.waitForExistence(timeout: 3))
        startExercise.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let logSet = app.buttons["Log Set 1"].firstMatch
        XCTAssertTrue(logSet.waitForExistence(timeout: 3))
        logSet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(1)
        app.swipeUp()
        let finish = app.buttons["Finish Exercise"].firstMatch
        XCTAssertTrue(finish.waitForExistence(timeout: 3))
        finish.tap()
        sleep(1)

        // Regression (day-switch bug): after finishing bench on a push
        // session, the queue must still be the PUSH queue.
        XCTAssertTrue(app.navigationBars["Push · The Gym"].waitForExistence(timeout: 5))
        snap(app, "30_queue_still_push")

        // Tapping the completed exercise opens the editor for today's session.
        let doneLabel = app.staticTexts["Bench Press"].firstMatch
        XCTAssertTrue(doneLabel.waitForExistence(timeout: 5))
        doneLabel.tap()
        XCTAssertTrue(app.staticTexts["Edit Session"].firstMatch.waitForExistence(timeout: 5))
        snap(app, "31_edit_mid_session")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // "Close" renders its full label (the old truncation bug) — the
        // visual proof is snap 30; here just assert it's present.
        XCTAssertTrue(app.buttons["Close"].firstMatch.exists)

        // End the session through the summary — plain buttons, so no
        // confirmation-dialog taps to go astray.
        let finishSession = app.buttons["Finish Session"].firstMatch
        XCTAssertTrue(finishSession.waitForExistence(timeout: 3))
        finishSession.tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        sleep(1)
        done.tap()

        // ---- Measurements ----
        let bodyTab = app.tabBars.buttons["Body"]
        XCTAssertTrue(bodyTab.waitForExistence(timeout: 5))
        bodyTab.tap()
        sleep(2)
        snap(app, "32a_body_tab")
        let measureSegment = app.buttons["Measure"].firstMatch
        if measureSegment.waitForExistence(timeout: 5) {
            measureSegment.tap()
        } else if app.segmentedControls.buttons["Measure"].firstMatch.exists {
            app.segmentedControls.buttons["Measure"].firstMatch.tap()
        } else {
            app.staticTexts["Measure"].firstMatch.tap()
        }
        sleep(1)
        snap(app, "32_measure_empty")

        // Each site card carries its own add button; scroll the waist card in.
        let addWaist = app.buttons["Add Waist"].firstMatch
        var swipes = 0
        while (!addWaist.exists || !addWaist.isHittable) && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(addWaist.isHittable)
        addWaist.tap()
        XCTAssertTrue(app.staticTexts["Log Measurement"].firstMatch.waitForExistence(timeout: 5))
        let inches = app.textFields["Inches"]
        XCTAssertTrue(inches.waitForExistence(timeout: 3))
        inches.tap()
        inches.typeText("34.5")
        snap(app, "33_measure_form")
        app.buttons["Save Measurement"].firstMatch.tap()
        sleep(1)

        // The waist card now leads with the new value.
        XCTAssertTrue(app.staticTexts["34.5"].waitForExistence(timeout: 5))
        snap(app, "34_measure_logged")

        // Expand the card's entries and open one for editing, date included.
        app.buttons["Waist entries"].firstMatch.tap()
        sleep(1)
        let entryRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS '34.5 in'")
        ).firstMatch
        XCTAssertTrue(entryRow.waitForExistence(timeout: 3))
        entryRow.tap()
        XCTAssertTrue(app.staticTexts["Edit Measurement"].firstMatch.waitForExistence(timeout: 5))
        snap(app, "35_measure_edit")
        app.buttons["Cancel"].firstMatch.tap()
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

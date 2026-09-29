import XCTest

final class LiveWorkspaceUITests: XCTestCase {
    private func launch(role: String) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--live-demo"]; app.launch()
        XCTAssertTrue(app.buttons["role-\(role)"].waitForExistence(timeout: 15))
        app.buttons["role-\(role)"].tap()
        let demo = app.buttons["live-demo"]
        XCTAssertTrue(app.navigationBars["기기 준비"].waitForExistence(timeout: 10))
        capture("connection-before-scroll")
        for _ in 0..<6 where !demo.exists || !demo.isHittable { app.collectionViews.firstMatch.swipeUp() }
        capture("connection-after-scroll")
        XCTAssertTrue(demo.isHittable)
        demo.tap()
        return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testCameraLandscapeAndCalibrationGate() {
        let app = launch(role: "camera")
        XCTAssertTrue(app.buttons["open-calibration"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        capture("phase1-camera")
        app.buttons["open-calibration"].tap()
        XCTAssertTrue(app.buttons["validate-calibration"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["live-corner-0"].isHittable)
        app.buttons["validate-calibration"].tap()
        let finish = app.buttons["finish-calibration"]
        XCTAssertTrue(finish.exists); XCTAssertFalse(finish.isEnabled)
        capture("phase1-calibration-independent-check")
    }
    func testMonitorShowsLargePlanAndVideo() {
        let app = launch(role: "monitor")
        let plan = app.descendants(matching: .any)["live-plan"].firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(plan.frame.width, app.frame.width * 0.40)
        XCTAssertTrue(app.descendants(matching: .any)["live-video"].firstMatch.exists)
        capture("phase1-monitor")
    }
    func testManualBoundaryRequiresConfirmation() {
        let app = launch(role: "camera")
        app.buttons["manual-stage"].tap()
        XCTAssertTrue(app.navigationBars["무대 범위 수정"].waitForExistence(timeout: 10))
        for _ in 0..<6 where !app.buttons["confirm-stage"].exists {
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(app.buttons["confirm-stage"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["confirm-stage"].isEnabled)
        let toggle = app.switches["confirm-bounds-check"]
        if !toggle.isHittable { app.collectionViews.firstMatch.swipeUp() }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["confirm-stage"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["confirm-stage"].isEnabled)
        capture("phase1-boundary-edit")
        app.buttons["confirm-stage"].tap()
        XCTAssertTrue(app.buttons["open-calibration"].waitForExistence(timeout: 10))
    }
}

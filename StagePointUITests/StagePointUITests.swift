import XCTest

final class StagePointUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["StagePoint"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["후보 1"].waitForExistence(timeout: 15), "실제 Vision 요청이 데모 사각형을 제안해야 합니다.")
        return app
    }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        if !element.isHittable { app.scrollViews["inspector"].swipeUp() }
        element.tap()
    }
    private func replace(_ field: XCUIElement, with value: String, app: XCUIApplication) {
        tap(field, in: app)
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + value)
        if app.buttons["dismiss-keyboard"].exists { app.buttons["dismiss-keyboard"].tap() }
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testRectangleProposalManualAdjustmentAndMapping() {
        let app = launch()
        screenshot("01-rectangle-proposal")
        let corner = app.descendants(matching: .any)["corner-0"]
        XCTAssertTrue(corner.exists)
        let start = corner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 10, dy: -6)))
        tap(app.buttons["apply-mapping"], in: app)
        let canvas = app.otherElements["stage-canvas"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).tap()
        XCTAssertTrue(app.staticTexts["actual-target-x"].waitForExistence(timeout: 5))
        screenshot("02-mapped-point")
    }
    func testStandardTargetScalesAndPersists() {
        let app = launch()
        replace(app.textFields["actual-width"], with: "9", app: app)
        replace(app.textFields["actual-depth"], with: "8", app: app)
        tap(app.buttons["apply-mapping"], in: app)
        app.buttons["open-templates"].tap()
        XCTAssertTrue(app.otherElements["standard-plan"].waitForExistence(timeout: 5))
        screenshot("03-standard-stage")
        let save = app.buttons["save-and-place"]
        if !save.isHittable { app.scrollViews["template-inspector"].swipeUp() }
        save.tap()
        XCTAssertTrue(app.staticTexts["actual-target-x"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["actual-target-x"].label.contains("3.00"))
        XCTAssertTrue(app.staticTexts["actual-target-y"].label.contains("6.00"))
        screenshot("04-normalized-placement")
        app.terminate(); app.launch()
        app.buttons["open-templates"].tap()
        app.buttons["saved-templates"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "표준 무대 6 × 4")).firstMatch.waitForExistence(timeout: 5))
    }
    func testMeasurementAndCalibrationInvalidation() {
        let app = launch()
        tap(app.buttons["apply-mapping"], in: app)
        app.buttons["정확도 검증"].tap()
        app.otherElements["stage-canvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).tap()
        replace(app.textFields["measurement-x"], with: "3", app: app)
        replace(app.textFields["measurement-y"], with: "2", app: app)
        XCTAssertTrue(app.staticTexts["measurement-error"].exists)
        screenshot("05-accuracy-measurement")
        tap(app.buttons["save-measurement"], in: app)
        XCTAssertTrue(app.staticTexts["measurement-count"].waitForExistence(timeout: 5))
        tap(app.buttons["전체 기록"], in: app)
        XCTAssertTrue(app.navigationBars["측정 기록"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "매핑 ")).firstMatch.exists)
        app.buttons["닫기"].tap()
        app.buttons["기준점 등록"].tap()
        replace(app.textFields["actual-width"], with: "7", app: app)
        XCTAssertFalse(app.buttons["정확도 검증"].isEnabled)
    }
}

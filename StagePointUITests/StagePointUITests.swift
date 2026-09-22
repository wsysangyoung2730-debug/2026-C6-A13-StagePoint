import XCTest

final class StagePointUITests: XCTestCase {
    func testLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["StagePoint"].waitForExistence(timeout: 10))
    }
}

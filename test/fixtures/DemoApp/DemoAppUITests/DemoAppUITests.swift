import XCTest

final class DemoAppUITests: XCTestCase {
    func testIncrementButton() {
        let app = XCUIApplication()
        app.launch()

        let button = app.buttons["incrementButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["Count: 1"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "after_increment"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

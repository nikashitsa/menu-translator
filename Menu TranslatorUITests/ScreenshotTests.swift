import Foundation
import XCTest

/// App Store screenshots, taken by `fastlane screenshots` (see `fastlane/Snapfile`).
///
/// The app runs in screenshot mode (`ScreenshotMode`): sample orders, the menu photo in
/// `fastlane/screenshot-menu.jpg` instead of the camera, and fixed translations. Names are numbered
/// in App Store order.
@MainActor
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Home → Scan → Translation (with a dish added) → language list.
    func testScanAndTranslate() {
        let app = launch()
        XCTAssertTrue(app.buttons["recentOrder"].firstMatch.waitForExistence(timeout: 10))
        snapshot("05-Home")

        app.buttons["Scan menu"].tap()
        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 10))
        sleep(1)
        snapshot("06-Scan")

        app.buttons["Take photo"].tap()
        let addToOrder = app.buttons["Add to order"]
        XCTAssertTrue(addToOrder.waitForExistence(timeout: 30), "The demo dish wasn't read")
        addToOrder.tap()
        // The dish flies to the order button, which then shows the new total.
        sleep(2)
        snapshot("01-Translation")

        app.buttons["languageButton"].tap()
        XCTAssertTrue(app.staticTexts["Choose language"].waitForExistence(timeout: 10))
        sleep(1)
        snapshot("03-Languages")
    }

    /// Home → saved order → dish details.
    func testSavedOrder() {
        let app = launch()
        let order = app.buttons["recentOrder"].firstMatch
        XCTAssertTrue(order.waitForExistence(timeout: 10))
        order.tap()
        let dish = app.buttons["dishRow"].firstMatch
        XCTAssertTrue(dish.waitForExistence(timeout: 10))
        snapshot("02-Order")

        dish.tap()
        XCTAssertTrue(app.buttons["Edit price"].firstMatch.waitForExistence(timeout: 10) || app.staticTexts["Origin"].waitForExistence(timeout: 10))
        snapshot("04-DishDetails")
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += [
            "-screenshots",
            // Read through UserDefaults' argument domain by @AppStorage.
            "-hasCompletedOnboarding", "YES",
            "-menuLanguage", "es",
            "-menuCurrency", "MXN",
        ]
        // The Simulator reads the Mac's file system, so the photo stays out of the app bundle.
        app.launchEnvironment["SCREENSHOT_MENU_PHOTO"] = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "fastlane/screenshot-menu.jpg")
            .path
        app.launch()
        return app
    }
}

import XCTest

/// End-to-end tests that walk through the main screens with demo data
/// and attach a screenshot of each one (collected by CI on pull requests).
/// Screenshot names start with a number so they sort in reading order.
final class BudgetUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-demo-data",
            // UserDefaults read by @AppStorage
            "-monthlyIncome", "2500",
            "-currencyCode", "EUR",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()
    }

    /// Show the screen at the time of failure in the PR comment too.
    override func tearDown() {
        if let run = testRun, run.failureCount > 0 {
            // name is "-[BudgetUITests testMonthly]"
            let method = name.split(separator: " ").last.map { String($0.dropLast()) } ?? "test"
            snapshot("99-failure-\(method)")
        }
        super.tearDown()
    }

    func testMonthly() {
        XCTAssertTrue(app.staticTexts["You have"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Rent"].exists)
        snapshot("01-monthly")

        // Add a recurring charge
        app.buttons["Add charge"].tap()
        let title = app.textFields["charge-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Phone")
        let amount = app.textFields["charge-amount"]
        amount.tap()
        amount.typeText("15")
        title.tap() // commit the amount field
        snapshot("02-new-charge")
        app.buttons["Save"].tap()
        XCTAssertTrue(scrollUntilVisible(app.staticTexts["Phone"]), "New charge should be listed")
        snapshot("03-monthly-with-new-charge")
    }

    func testInvestments() {
        openTab("Investments")
        XCTAssertTrue(app.staticTexts["All that's ours 💎"].waitForExistence(timeout: 10))
        snapshot("06-investments")

        // An investment and its snapshots
        let etf = app.staticTexts["MSCI World"]
        XCTAssertTrue(scrollUntilVisible(etf))
        etf.tap()
        XCTAssertTrue(app.staticTexts["Invested so far"].waitForExistence(timeout: 5))
        snapshot("07-investment-detail")
        app.swipeUp()
        snapshot("08-investment-history")

        // New snapshot starts from the previous one
        let newSnapshot = app.buttons["New snapshot"]
        XCTAssertTrue(scrollUntilVisible(newSnapshot))
        newSnapshot.tap()
        XCTAssertTrue(app.navigationBars["New snapshot"].waitForExistence(timeout: 5))
        let quantity = app.textFields["snapshot-quantity"]
        XCTAssertTrue(quantity.exists)
        XCTAssertEqual(quantity.value as? String, "24", "Quantity should be pre-filled from the last snapshot")
        snapshot("09-new-snapshot")
        app.buttons["Cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Home loan
        let home = app.staticTexts["Our apartment"]
        XCTAssertTrue(scrollUntilVisible(home))
        home.tap()
        XCTAssertTrue(app.staticTexts["Already repaid"].waitForExistence(timeout: 5))
        snapshot("10-home-loan")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Snapshot of everything
        app.buttons["Snapshot all"].tap()
        XCTAssertTrue(app.navigationBars["Snapshot of everything"].waitForExistence(timeout: 5))
        snapshot("11-snapshot-all")
        app.buttons["Cancel"].tap()
    }

    func testSettings() {
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        snapshot("12-settings")
        app.buttons["Done"].tap()
    }

    // MARK: - Helpers

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Tab bar at the bottom on iPhone, at the top on iPad (iOS 18+).
    private func openTab(_ name: String) {
        let tabBarButton = app.tabBars.buttons[name]
        if tabBarButton.exists {
            tabBarButton.tap()
        } else {
            app.buttons[name].firstMatch.tap()
        }
    }

    @discardableResult
    private func scrollUntilVisible(_ element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists
    }
}

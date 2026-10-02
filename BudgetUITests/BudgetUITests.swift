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
        XCTAssertTrue(app.staticTexts["Left after savings"].waitForExistence(timeout: 10))
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

        // Savings plan
        XCTAssertTrue(scrollUntilVisible(app.staticTexts["Monthly savings"]))
        XCTAssertTrue(scrollUntilVisible(app.buttons["Edit savings plan"]))
        snapshot("04-monthly-savings")
        app.buttons["Edit savings plan"].tap()
        XCTAssertTrue(app.navigationBars["Savings plan"].waitForExistence(timeout: 5))
        snapshot("05-savings-plan")
        app.buttons["Done"].tap()
    }

    func testIncome() {
        openTab("Income")
        XCTAssertTrue(app.staticTexts["Monthly income"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Freelance"].exists)
        snapshot("05a-income")

        // Income that only comes in some months: switch it on
        let tutoring = app.switches["income-toggle-Tutoring"]
        XCTAssertTrue(scrollUntilVisible(tutoring))
        XCTAssertEqual(tutoring.value as? String, "0", "Tutoring starts switched off")
        tutoring.tap()
        XCTAssertEqual(tutoring.value as? String, "1", "Tutoring should now count")

        // Add other income
        app.buttons["Add"].tap()
        app.buttons["Add income"].tap()
        let title = app.textFields["income-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Bonus")
        let amount = app.textFields["income-amount"]
        amount.tap()
        amount.typeText("300")
        title.tap() // commit the amount field
        snapshot("05b-new-income")
        app.buttons["Save"].tap()
        XCTAssertTrue(scrollUntilVisible(app.staticTexts["Bonus"]), "New income should be listed")

        // Money lent, followed through snapshots
        let lucas = app.staticTexts["Lucas"]
        XCTAssertTrue(scrollUntilVisible(lucas))
        snapshot("05c-money-lent")
        lucas.tap()
        XCTAssertTrue(app.staticTexts["Already repaid"].waitForExistence(timeout: 5))
        snapshot("05d-money-lent-detail")

        // A new snapshot starts from what was left last time
        let newSnapshot = app.buttons["New snapshot"]
        XCTAssertTrue(scrollUntilVisible(newSnapshot))
        newSnapshot.tap()
        XCTAssertTrue(app.navigationBars["New snapshot"].waitForExistence(timeout: 5))
        let remaining = app.textFields["lending-remaining"]
        XCTAssertEqual(remaining.value as? String, "1500", "Should be pre-filled with the last snapshot")
        remaining.tap()
        remaining.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "1250")
        snapshot("05e-new-lending-snapshot")
        app.buttons["Save"].tap()
        let left = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '1,250'")).firstMatch
        XCTAssertTrue(left.waitForExistence(timeout: 5), "Left to repay should go down")
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testInvestments() {
        openTab("Investments")
        XCTAssertTrue(app.staticTexts["Investments value"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Apartment"].exists, "Home is hidden in investments mode")
        snapshot("06-investments")

        // Net worth includes the home and its loan
        app.buttons["Net worth"].tap()
        let homeEquity = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Home equity'")).firstMatch
        XCTAssertTrue(homeEquity.waitForExistence(timeout: 5), "Net worth shows the home equity")
        let moneyLent = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Money lent'")).firstMatch
        XCTAssertTrue(moneyLent.exists, "Net worth counts money lent")
        snapshot("06-net-worth")
        XCTAssertTrue(scrollUntilVisible(app.staticTexts["Saved per month"]))
        snapshot("06-saved-per-month")

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
        XCTAssertEqual(quantity.value as? String, "21", "Quantity should be pre-filled from the last snapshot")
        snapshot("09-new-snapshot")
        app.buttons["Cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Home loan
        let home = app.staticTexts["Apartment"]
        XCTAssertTrue(scrollUntilVisible(home))
        home.tap()
        XCTAssertTrue(app.staticTexts["Already repaid"].waitForExistence(timeout: 5))
        snapshot("10-home-loan")

        // Correct "left to repay" from Edit, saving straight after typing
        app.buttons["Edit"].tap()
        let remaining = app.textFields["loan-remaining"]
        XCTAssertTrue(remaining.waitForExistence(timeout: 5))
        remaining.tap()
        let current = remaining.value as? String ?? ""
        remaining.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "150000")
        snapshot("10-edit-loan")
        app.buttons["Save"].tap()
        let updated = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '150,000'")).firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 5), "Left to repay should be updated")
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

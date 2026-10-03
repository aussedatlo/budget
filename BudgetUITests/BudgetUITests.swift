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

        // Money lent, followed through what's left to repay
        let lucas = app.staticTexts["Lucas"]
        XCTAssertTrue(scrollUntilVisible(lucas))
        snapshot("05c-money-lent")
        lucas.tap()
        XCTAssertTrue(app.staticTexts["Already repaid"].waitForExistence(timeout: 5))
        snapshot("05d-money-lent-detail")

        // Updating starts from what was left last time
        let update = app.buttons["Update what's left"]
        XCTAssertTrue(scrollUntilVisible(update))
        update.tap()
        XCTAssertTrue(app.navigationBars["Update what's left"].waitForExistence(timeout: 5))
        let remaining = app.textFields["lending-remaining"]
        XCTAssertEqual(remaining.value as? String, "1500", "Should be pre-filled with what was left")
        remaining.tap()
        remaining.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "1250")
        snapshot("05e-update-money-lent")
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

        // An investment and its history
        let etf = app.staticTexts["MSCI World"]
        XCTAssertTrue(scrollUntilVisible(etf))
        etf.tap()
        XCTAssertTrue(app.staticTexts["Invested so far"].waitForExistence(timeout: 5))
        snapshot("07-investment-detail")
        app.swipeUp()
        snapshot("08-investment-history")

        // Updating starts from the current values
        let update = app.buttons["Update values"]
        XCTAssertTrue(scrollUntilVisible(update))
        update.tap()
        XCTAssertTrue(app.navigationBars["Update values"].waitForExistence(timeout: 5))
        let quantity = app.textFields["snapshot-quantity"]
        XCTAssertTrue(quantity.exists)
        XCTAssertEqual(quantity.value as? String, "21", "Quantity should be pre-filled with the current one")
        snapshot("09-update-values")
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

        // The snapshot of everything can be taken from any tab
        app.buttons["Snapshot"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Snapshot"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    func testStats() {
        openTab("Stats")
        XCTAssertTrue(app.staticTexts["Net worth over time"].waitForExistence(timeout: 10))
        snapshot("11-stats")

        // Snapshot of everything: pre-filled with the current state, to check and fix
        app.buttons["Take a snapshot"].tap()
        XCTAssertTrue(app.navigationBars["Snapshot"].waitForExistence(timeout: 5))
        let income = app.textFields["snapshot-main-income"]
        XCTAssertTrue(income.waitForExistence(timeout: 5))
        XCTAssertEqual(income.value as? String, "2500", "Main income should be pre-filled")
        snapshot("11a-snapshot")

        // Forgot the rent went up: fix it here, it becomes the current charge
        let rent = app.textFields["snapshot-charge-Rent"]
        XCTAssertTrue(scrollUntilVisible(rent))
        XCTAssertEqual(rent.value as? String, "850", "Charges should be pre-filled")
        rent.tap()
        rent.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "900")
        snapshot("11b-snapshot-fixed")
        app.buttons["Save"].tap()

        // Evolution, snapshot after snapshot
        XCTAssertTrue(app.staticTexts["Net worth over time"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollUntilVisible(app.staticTexts["Saved per month"]))
        snapshot("11c-stats-savings")
        XCTAssertTrue(scrollUntilVisible(app.staticTexts["Monthly budget"]))
        snapshot("11d-stats-budget")
        XCTAssertTrue(scrollUntilVisible(app.staticTexts["Snapshots"]))
        app.swipeUp()
        snapshot("11e-stats-snapshots")

        // The correction made in the snapshot is the new current state
        openTab("Month")
        let newRent = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '900'")).firstMatch
        XCTAssertTrue(newRent.waitForExistence(timeout: 5), "Rent should be updated")
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

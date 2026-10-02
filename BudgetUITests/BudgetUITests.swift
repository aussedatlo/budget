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
            "-monthlyBudget", "2000",
            "-currencyCode", "EUR",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()
    }

    /// Show the screen at the time of failure in the PR comment too.
    override func tearDown() {
        if let run = testRun, run.failureCount > 0 {
            // name is "-[BudgetUITests testExpenses]"
            let method = name.split(separator: " ").last.map { String($0.dropLast()) } ?? "test"
            snapshot("99-failure-\(method)")
        }
        super.tearDown()
    }

    func testExpenses() {
        XCTAssertTrue(app.staticTexts["Spent this month"].waitForExistence(timeout: 10))
        snapshot("01-expenses")

        scrollUntilVisible(app.staticTexts["Expenses"])
        snapshot("02-expenses-list")

        // Add an expense
        app.buttons["Add expense"].tap()
        let amount = app.textFields["expense-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("42")
        let title = app.textFields["expense-title"]
        title.tap()
        title.typeText("Book")
        snapshot("03-new-expense")
        app.buttons["Save"].tap()
        XCTAssertTrue(scrollUntilVisible(app.staticTexts["Book"]), "New expense should be listed")

        // Fixed charges
        app.buttons["Fixed charges"].tap()
        XCTAssertTrue(app.staticTexts["Rent"].waitForExistence(timeout: 5))
        snapshot("04-fixed-charges")
        app.buttons["Done"].tap()

        // Previous month: shown from the top, with its own title
        app.buttons["Previous month"].tap()
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
        let monthTitle = previousMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "en_US")))
        XCTAssertTrue(app.staticTexts[monthTitle].waitForExistence(timeout: 5), "Title should be \(monthTitle)")
        XCTAssertTrue(app.staticTexts["Spent this month"].waitForExistence(timeout: 5))
        snapshot("05-previous-month")
    }

    func testInvestments() {
        openTab("Investments")
        XCTAssertTrue(app.staticTexts["Portfolio value"].waitForExistence(timeout: 10))
        snapshot("06-investments")

        app.staticTexts["MSCI World"].tap()
        XCTAssertTrue(app.staticTexts["Avg. buy price"].waitForExistence(timeout: 5))
        snapshot("07-investment-detail")

        app.swipeUp()
        snapshot("08-investment-history")

        XCTAssertTrue(scrollUntilVisible(app.buttons["Add trade"]))
        app.buttons["Add trade"].tap()
        XCTAssertTrue(app.staticTexts["Amount used"].waitForExistence(timeout: 5))
        snapshot("09-new-trade")
        app.buttons["Cancel"].tap()

        app.navigationBars.buttons["Investments"].tap()
        app.buttons["Snapshot all"].tap()
        XCTAssertTrue(app.staticTexts["Unit prices"].waitForExistence(timeout: 5))
        snapshot("10-snapshot-all")
        app.buttons["Cancel"].tap()
    }

    func testSettings() {
        openTab("Settings")
        XCTAssertTrue(app.staticTexts["Monthly budget"].waitForExistence(timeout: 10))
        snapshot("11-settings")
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

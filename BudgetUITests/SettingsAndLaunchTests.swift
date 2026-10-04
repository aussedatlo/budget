import XCTest

/// Feature: Settings.
final class SettingsTests: BudgetUITestCase {
    func testOpenSettings() {
        when("I tap Settings") {
            tap(button("Settings"))
        }
        then("Settings shows the currency, the version and the icon credit") {
            expect(screen("Settings"))
            expect(anything(containing: "Currency"))
            expect(anything(containing: "Version"))
            expect(anything(containing: "Icons by OpenMoji"))
        }
        when("I tap Done") {
            button("Done").tap()
        }
        then("Settings close") {
            expectNo(screen("Settings"))
        }
    }

    func testChangeTheCurrency() {
        given("the currency saved in the app") {
            // Without -currencyCode, which would override what the app saves
            launch(currency: nil)
        }
        when("I pick GBP in Settings") {
            tap(button("Settings"))
            tap(button(containing: "Currency"))
            pick("GBP")
        }
        then("Settings stay open") {
            expect(screen("Settings"))
        }
        and("amounts are shown in pounds, with no conversion") {
            button("Done").tap()
            expect(text("£1,609.02"))
        }
    }
}

/// Feature: Launch and stored data.
final class LaunchTests: BudgetUITestCase {
    // Starts from the real store rather than the demo data
    override func setUp() {
        continueAfterFailure = false
    }

    func testMoveAnOldMainIncomeIntoAnIncomeLine() {
        given("an earlier version saved a main income of 2,500 €") {
            launch(demoData: false, arguments: ["-monthlyIncome", "2500"])
        }
        then("an income line Salary of 2,500 € is added, switched on") {
            openTab("Income")
            expect(text("Salary"), timeout: 10)
            expect(text("€2,500.00"))
            XCTAssertEqual(toggle("income-toggle-Salary").value as? String, "1")
        }
        when("the app starts again") {
            launch(demoData: false)
        }
        then("no second Salary line is added") {
            openTab("Income")
            expect(text("Salary"), timeout: 10)
            XCTAssertEqual(count(of: "Salary"), 1)
        }
    }
}

import XCTest

/// Feature: Tab headers.
/// Budget, Income and Wealth open with the same header: one icon, one value,
/// and one bar showing what the value is made of, with a legend.
final class TabHeaderTests: BudgetUITestCase {
    private var bar: XCUIElement { app.descendants(matching: .any)["header-bar"].firstMatch }

    func testTheSameHeaderOnEveryTab() {
        given("the demo data")
        for (tab, icon, title) in [("Budget", "budget-banknote", "Left after savings"),
                                   ("Income", "money-bag", "Monthly income"),
                                   ("Wealth", "seedling", "Investments value")] {
            when("I open \(tab)") {
                openTab(tab)
            }
            then("its header shows its icon, \(title), one large amount and a bar with a legend") {
                let mascot = app.descendants(matching: .any)[icon].firstMatch
                expect(mascot, timeout: 10)
                expect(text(title))
                XCTAssertLessThanOrEqual(mascot.frame.maxX, text(title).frame.minX)
                expect(bar)
                XCTAssertTrue(isAbove(text(title), bar))
            }
        }
    }

    func testIncomeBarOneColorPerIncomeLineAndMoneyLent() {
        given("the demo data on the Income tab") {
            openTab("Income")
        }
        then("the bar shows Salary €2,500.00, Freelance €400.00 and Money lent €250.00") {
            expect(legend("Salary"), timeout: 10)
            XCTAssertTrue(legend("Salary").label.contains("€2,500.00"))
            XCTAssertTrue(legend("Freelance").label.contains("€400.00"))
            XCTAssertTrue(legend("Money lent").label.contains("€250.00"))
        }
        and("Tutoring, switched off, is not in the bar") {
            XCTAssertFalse(legend("Tutoring").exists)
        }
    }

    func testWealthBarOneColorPerTypeOfInvestment() {
        given("the demo data on the Wealth tab") {
            openTab("Wealth")
        }
        then("the bar shows ETF, Crypto, Savings and Precious metal, each with its value and share") {
            expect(legend("ETF"), timeout: 10)
            for kind in ["ETF", "Crypto", "Savings", "Precious metal"] {
                XCTAssertTrue(legend(kind).label.contains("€"), kind)
                XCTAssertTrue(legend(kind).label.contains("%"), kind)
            }
        }
    }

    func testNetWorthAddsHomeEquityAndMoneyLentToTheBar() {
        given("net worth is shown") {
            openTab("Wealth")
            tap(button("Show net worth"))
            expect(text("Net worth"))
        }
        then("the bar also shows Home equity and Money lent") {
            expect(legend("Home equity"))
            expect(legend("Money lent"))
        }
    }

    func testHiddenInvestmentsLeaveTheBar() {
        given("Bitcoin is hidden") {
            openTab("Wealth")
            tap(button("Hide Bitcoin"))
            expect(text("1 hidden"))
        }
        then("Crypto is no longer in the Wealth bar") {
            expectNo(legend("Crypto"))
        }
    }
}

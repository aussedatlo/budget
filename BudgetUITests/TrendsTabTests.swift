import XCTest

/// Feature: Trends header.
final class TrendsHeaderTests: BudgetUITestCase {
    func testThisMonthsSnapshotIsTaken() {
        given("the demo data") {
            openTab("Trends")
        }
        then("the title is Trends and the header shows net worth and how it moved") {
            expect(screen("Trends"), timeout: 10)
            expect(text("Net worth"))
            expect(text(containing: " since "))
        }
        and("it says this month's snapshot is taken, with nothing to take") {
            expect(text("\(monthName(monthsAgo: 0)) snapshot taken"))
            XCTAssertFalse(button("Take a snapshot").exists)
        }
        screenshot("08-trends")
    }

    func testThisMonthsSnapshotIsStillToTake() {
        given("the last snapshot is from \(monthName(monthsAgo: 2))") {
            launch(missedMonths: 1)
            openTab("Trends")
        }
        then("the header says when the last one was taken and offers to take one") {
            expect(text("Last snapshot \(monthName(monthsAgo: 2))"), timeout: 10)
            expect(text(containing: "Once a month or so"))
            expect(button("Take a snapshot"))
        }
        when("I tap Take a snapshot") {
            button("Take a snapshot").tap()
        }
        then("the snapshot opens") {
            expect(screen("Snapshot"))
        }
    }
}

/// Feature: Charts.
final class TrendsChartsTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Trends")
    }

    func testNetWorthOverTime() {
        then("Net worth over time is shown, with its parts and snapshot dots explained") {
            expect(text("Net worth over time"), timeout: 10)
            expect(text("Dots are your snapshots. Tap the chart to see a date."))
        }
    }

    func testInvestmentsCharts() {
        given("there are investments")
        then("the Investments chart is shown") {
            XCTAssertTrue(scrollUntilVisible(text("Investments")))
        }
        and("Saved per month shows this month, the plan and the monthly average") {
            XCTAssertTrue(scrollUntilVisible(text("Saved per month")))
            expect(text(containing: "This month €"))
            expect(text("Plan €500.00"))
            expect(text(containing: "avg €"))
        }
    }

    func testMonthlyBudgetChart() {
        given("at least two snapshots")
        then("Monthly budget shows the latest income, saving rate and what is left") {
            XCTAssertTrue(scrollUntilVisible(text("Monthly budget")))
            expect(text(containing: "Income €"))
            expect(text(containing: "Saving "))
            expect(text(containing: "left €"))
        }
    }

    func testRecurringChargesChart() {
        given("at least two snapshots")
        then("Recurring charges is shown with the latest total") {
            XCTAssertTrue(scrollUntilVisible(text("Recurring charges")))
            expect(text("€1,040.98"))
        }
    }

    func testTapAChartToOpenItsSnapshot() {
        let title = text("Monthly budget")
        given("the Monthly budget chart") {
            XCTAssertTrue(scrollUntilVisible(title))
            app.swipeUp() // the whole chart on screen
        }
        when("I tap it") {
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            origin.withOffset(CGVector(dx: app.frame.width / 2, dy: title.frame.maxY + 100)).tap()
        }
        then("the bar under it shows that month's income and what was left") {
            expect(text(containing: " · left €"))
            expect(button("Open snapshot"))
        }
        when("I tap Open snapshot") {
            button("Open snapshot").tap()
        }
        then("that snapshot opens") {
            expect(button("Done"))
        }
    }
}

/// Feature: Snapshot list.
final class SnapshotListTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Trends")
    }

    func testSeeTheSnapshots() {
        then("Snapshots lists one row per month, newest first") {
            XCTAssertTrue(scrollUntilVisible(text("Snapshots"), maxSwipes: 10))
            let current = text(monthName(monthsAgo: 0))
            let previous = text(monthName(monthsAgo: 1))
            XCTAssertTrue(scrollUntilVisible(current))
            XCTAssertTrue(isAbove(current, previous))
        }
        and("each row shows what was left each month") {
            expect(text(containing: "a month"))
        }
    }

    func testOpenASnapshot() {
        let current = monthName(monthsAgo: 0)
        when("I tap \(current)") {
            tap(text(current))
        }
        then("it shows the budget and net worth of that month") {
            expect(screen(current))
            expect(header("Monthly budget"))
            expect(header("Net worth"))
            expect(text("Home equity"))
        }
        and("the income lines as they were") {
            XCTAssertTrue(dragUntilVisible(text("Salary")))
            XCTAssertTrue(dragUntilVisible(text("Repaid by Lucas")))
        }
        when("I tap Done") {
            button("Done").tap()
        }
        then("it closes") {
            expectNo(screen(current))
        }
    }
}

/// Feature: Deleting a snapshot.
final class DeletingASnapshotTests: BudgetUITestCase {
    private var current: String { monthName(monthsAgo: 0) }

    override func setUp() {
        super.setUp()
        openTab("Trends")
        XCTAssertTrue(scrollUntilVisible(text(current), maxSwipes: 10), "This month's snapshot should be listed")
        text(current).tap()
        expect(screen(current))
        tap(button("Delete this snapshot"))
        expect(text("Delete the \(current) snapshot?"))
    }

    func testDeleteTheSnapshotOnly() {
        when("I delete the snapshot only") {
            button("Delete the snapshot only").tap()
        }
        then("it is no longer listed and this month's snapshot is to take again") {
            expectNo(screen(current))
            scrollToTop()
            expect(button("Take a snapshot"))
        }
        and("investments keep this month's values") {
            openTab("Wealth")
            expect(text("€10,290.00"))
        }
    }

    func testDeleteTheSnapshotAndThatMonthsValues() {
        when("I delete it with that month's values") {
            button("Delete it and that month's values").tap()
        }
        then("it is no longer listed") {
            expectNo(screen(current))
            scrollToTop()
            expect(button("Take a snapshot"))
        }
        and("the values recorded this month are removed") {
            openTab("Wealth")
            expect(text("MSCI World"))
            XCTAssertFalse(text("€10,290.00").exists)
        }
    }
}

import XCTest

/// Feature: Monthly income.
/// The income lines switched on, plus what money lent brings back this month.
final class MonthlyIncomeTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Income")
    }

    func testSeeTheMonthlyIncome() {
        given("the demo data")
        then("the title is Income and the monthly income is 3,150 €") {
            expect(screen("Income"), timeout: 10)
            expect(text("Monthly income"))
            expect(text("€3,150.00"))
        }
        and("the chips show the income lines and what is repaid to me") {
            expect(text("Income €2,900.00"))
            expect(text("Repaid to you €250.00"))
        }
        and("the income lines are listed oldest first") {
            XCTAssertTrue(isAbove(text("Salary"), text("Freelance")))
            XCTAssertTrue(isAbove(text("Freelance"), text("Tutoring")))
        }
        screenshot("02-income")
    }

    func testSwitchOnIncomeThatOnlyComesInSomeMonths() {
        let tutoring = toggle("income-toggle-Tutoring")
        given("Tutoring 150 € is switched off") {
            XCTAssertTrue(scrollUntilVisible(tutoring))
            XCTAssertEqual(tutoring.value as? String, "0")
            expect(text("Not this month"))
        }
        when("I switch Tutoring on") {
            tutoring.tap()
        }
        then("it is counted this month") {
            XCTAssertEqual(tutoring.value as? String, "1")
            expectNo(text("Not this month"))
        }
        and("the monthly income goes up by 150 €") {
            expect(text("€3,300.00"))
        }
        and("so does the income on the Budget tab") {
            openTab("Budget")
            expect(button("open-income"))
            XCTAssertTrue(button("open-income").label.contains("€3,300.00"))
        }
    }

    func testSwitchOffIncomeForThisMonth() {
        when("I switch Freelance off") {
            tap(toggle("income-toggle-Freelance"))
        }
        then("it stays listed, but isn't counted") {
            expect(text("Freelance"))
            XCTAssertEqual(toggle("income-toggle-Freelance").value as? String, "0")
            expect(text("€2,750.00"))
        }
    }

    func testRemindWhenAnIncomeWasLastCounted() {
        let lastMonthCounted = monthName(monthsAgo: 2)
        given("the latest snapshot counting Freelance was taken in \(lastMonthCounted)")
        then("Freelance says when it was last counted") {
            expect(text("Counted this month · last counted in \(lastMonthCounted)"))
        }
        and("Salary, counted in this month's snapshot, has no reminder") {
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'last counted'")).count, 1)
        }
    }
}

/// Feature: Income lines.
final class IncomeLinesTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Income")
    }

    private func openNewIncome() {
        tap(button("Add"))
        pick("Add income")
        expect(screen("New income"))
    }

    func testAddAnIncomeLine() {
        when("I add the income Bonus of 300 €") {
            openNewIncome()
            type("Bonus", into: field("income-title"))
            type("300", into: field("income-amount"))
            save()
        }
        then("Bonus is listed last, switched on") {
            XCTAssertTrue(scrollUntilVisible(text("Bonus")))
            XCTAssertTrue(isAbove(text("Tutoring"), text("Bonus")))
            XCTAssertEqual(toggle("income-toggle-Bonus").value as? String, "1")
        }
        and("the monthly income goes up by 300 €") {
            scrollToTop()
            expect(text("€3,450.00"))
        }
    }

    func testAddAnIncomeThatDoesNotComeInThisMonth() {
        when("I add an income switched off for this month") {
            openNewIncome()
            type("Gift", into: field("income-title"))
            type("100", into: field("income-amount"))
            flip(toggle("Counted this month"))
            save()
        }
        then("it is listed but not counted") {
            XCTAssertTrue(scrollUntilVisible(text("Gift")))
            XCTAssertEqual(toggle("income-toggle-Gift").value as? String, "0")
            scrollToTop()
            expect(text("€3,150.00"))
        }
    }

    func testSaveNeedsATitleAndAnAmountAboveZero() {
        given("the New income form") {
            openNewIncome()
        }
        then("Save is disabled until there is a title and an amount above 0") {
            XCTAssertFalse(button("Save").isEnabled)
            type("Bonus", into: field("income-title"))
            XCTAssertFalse(button("Save").isEnabled, "No amount yet")
            type("0", into: field("income-amount"))
            XCTAssertFalse(button("Save").isEnabled, "An amount of 0")
            replace(field("income-amount"), with: "300")
            XCTAssertTrue(button("Save").isEnabled)
        }
    }

    func testEditAnIncomeLine() {
        when("I tap the Salary card") {
            tap(text("Salary"))
        }
        then("Edit income opens with its amount") {
            expect(screen("Edit income"))
            XCTAssertEqual(field("income-amount").value as? String, "2500")
        }
        when("I change the amount to 2,600 and save") {
            replace(field("income-amount"), with: "2600")
            save()
        }
        then("Salary shows 2,600 € and the totals follow") {
            expect(text("€2,600.00"))
            expect(text("€3,250.00"))
        }
    }

    func testDeleteAnIncomeLine() {
        when("I delete Freelance from its form") {
            tap(text("Freelance"))
            tap(button("Delete this income"))
            answer("Delete Freelance?", with: "Delete")
        }
        then("Freelance is no longer listed and the monthly income goes down") {
            expectNo(text("Freelance"))
            expect(text("€2,750.00"))
        }
    }
}

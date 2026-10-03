import XCTest

/// Feature: Monthly budget.
/// What is left = income counted this month − recurring charges − planned savings.
final class MonthlyBudgetTests: BudgetUITestCase {
    func testSeeWhatIsLeftAfterSavings() {
        given("the demo data")
        then("the title is Budget") {
            expect(screen("Budget"), timeout: 10)
        }
        and("the header says what is left after savings") {
            expect(text("Left after savings"))
            expect(text("€1,609.02"))
        }
        and("under it the income it comes from") {
            XCTAssertTrue(button("open-income").label.contains("€3,150.00"))
        }
        and("the bar splits income into charges, savings and what is left") {
            expect(text("Charges"))
            expect(text("Savings"))
            expect(text("Left"))
        }
        screenshot("01-budget")
    }

    func testOverBudget() {
        given("charges and savings are larger than income") {
            tap(text("Rent"))
            replace(field("charge-amount"), with: "5000")
            save()
        }
        then("the header says Over budget") {
            expect(text("Over budget"))
        }
    }

    func testOpenTheIncomeTabFromTheIncomeLine() {
        when("I tap the income under what is left") {
            tap(button("open-income"))
        }
        then("the Income tab opens") {
            expect(text("Monthly income"))
        }
    }

    func testChargesAreSortedByAmount() {
        given("the charges Rent 850 €, Electricity 64 € and Netflix 13.49 €")
        then("they are listed Rent, Electricity, Netflix") {
            expect(text("Rent"), timeout: 10)
            XCTAssertTrue(isAbove(text("Rent"), text("Electricity")))
            XCTAssertTrue(isAbove(text("Electricity"), text("Netflix")))
        }
        and("each card shows its category") {
            expect(text("Housing"))
            expect(text("Subscriptions"))
        }
        and("the Recurring charges heading shows their total") {
            expect(text("€1,040.98"))
        }
    }
}

/// Feature: Recurring charges.
final class RecurringChargesTests: BudgetUITestCase {
    func testAddACharge() {
        when("I add the charge Phone of 15 €") {
            tap(button("Add charge"))
            type("Phone", into: field("charge-title"))
            type("15", into: field("charge-amount"))
            save()
        }
        then("Phone is listed among the charges") {
            expect(text("Phone"))
        }
        and("the total and what is left are updated") {
            expect(text("€1,055.98"))
            expect(text("€1,594.02"))
        }
    }

    func testSaveIsOnlyPossibleWithATitleAndAnAmount() {
        when("I open New charge") {
            tap(button("Add charge"))
            expect(screen("New charge"))
        }
        then("Save is disabled without a title or an amount") {
            XCTAssertFalse(button("Save").isEnabled)
            type("Phone", into: field("charge-title"))
            XCTAssertFalse(button("Save").isEnabled, "No amount yet")
            type("0", into: field("charge-amount"))
            XCTAssertFalse(button("Save").isEnabled, "An amount of 0")
        }
        and("Save is enabled with both") {
            replace(field("charge-amount"), with: "15")
            XCTAssertTrue(button("Save").isEnabled)
        }
    }

    func testEditACharge() {
        when("I tap the Rent card") {
            tap(text("Rent"))
        }
        then("Edit charge opens with its amount") {
            expect(screen("Edit charge"))
            XCTAssertEqual(field("charge-amount").value as? String, "850")
        }
        when("I change the amount to 900 and save") {
            replace(field("charge-amount"), with: "900")
            save()
        }
        then("Rent shows 900 €") {
            expect(text("€900.00"))
        }
    }

    func testCancelAChange() {
        when("I change Rent to 999 and cancel") {
            tap(text("Rent"))
            replace(field("charge-amount"), with: "999")
            cancel()
        }
        then("nothing is saved") {
            expectNo(screen("Edit charge"))
            expect(text("€850.00"))
            XCTAssertFalse(text("€999.00").exists)
        }
    }

    func testDeleteAChargeFromItsForm() {
        given("the Edit charge form for Netflix") {
            tap(text("Netflix"))
        }
        when("I tap Delete this charge and confirm") {
            tap(button("Delete this charge"))
            answer("Delete Netflix?", with: "Delete")
        }
        then("the form closes and Netflix is no longer listed") {
            expectNo(screen("Edit charge"))
            expectNo(text("Netflix"))
        }
    }

    func testDeleteAChargeFromTheList() {
        when("I long-press the Netflix card and choose Delete") {
            choose("Delete", inMenuOf: text("Netflix"))
        }
        then("I am asked first, and Netflix goes once I confirm") {
            answer("Delete Netflix?", with: "Delete")
            expectNo(text("Netflix"))
        }
    }
}

/// Feature: Monthly savings plan.
final class SavingsPlanTests: BudgetUITestCase {
    func testSeeThePlannedSavings() {
        given("Gold coins saves 300 € and Savings account 200 € each month")
        then("Monthly savings lists both with a total of 500 €") {
            expect(text("Monthly savings"), timeout: 10)
            expect(text("Gold coins"))
            expect(text("Savings account"))
            expect(text("€500.00"))
        }
        and("the plan can be edited") {
            expect(button("Edit savings plan"))
        }
    }

    func testEditTheSavingsPlan() {
        when("I set MSCI World to 100 € in the savings plan") {
            tap(button("Edit savings plan"))
            expect(screen("Savings plan"))
            type("100", into: field("MSCI World"))
            button("Done").tap()
        }
        then("MSCI World is listed under Monthly savings") {
            expect(text("MSCI World"))
        }
        and("what is left goes down by 100 €") {
            scrollToTop()
            expect(text("€1,509.02"))
        }
    }

    func testNoSavingsPlanYet() {
        when("I remove every investment from the plan") {
            tap(button("Edit savings plan"))
            clear(field("Gold coins"))
            clear(field("Savings account"))
            button("Done").tap()
        }
        then("I see No savings plan yet and Plan monthly savings") {
            expect(text("No savings plan yet"))
            expect(button("Plan monthly savings"))
        }
        and("the header says Left this month") {
            scrollToTop()
            expect(text("Left this month"))
        }
    }
}

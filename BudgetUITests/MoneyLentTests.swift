import XCTest

/// Feature: Money lent on the Income tab.
/// Followed by recording what is left to repay from time to time; an optional
/// monthly repayment counts as income until nothing is left.
final class MoneyLentTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Income")
    }

    func testSeeMoneyLent() {
        given("3,000 € lent to Lucas, 1,500 € left, repaid at 250 € a month")
        then("the Money lent section shows the total owed") {
            XCTAssertTrue(scrollUntilVisible(text("Money lent")))
            expect(text("€1,900.00 owed"))
        }
        and("Lucas's card shows the repayment, what is left and what is repaid") {
            XCTAssertTrue(scrollUntilVisible(text("Lucas")))
            expect(text("€250.00 a month"))
            expect(text("€3,000.00"))
            expect(text("Already repaid"))
        }
    }

    func testMoneyLentWithoutAMonthlyRepayment() {
        let lentOn = day(12, monthsAgo: 2)
        given("money lent to Emma on \(lentOn) with no monthly repayment")
        then("her card shows since when") {
            XCTAssertTrue(scrollUntilVisible(text("Emma")))
            expect(text("Since \(lentOn)"))
        }
        and("nothing from Emma counts as income") {
            scrollToTop()
            expect(legend("Money lent"))
            XCTAssertTrue(legend("Money lent").label.contains("€250.00"))
        }
    }

    func testARepaymentNeverCountsForMoreThanWhatIsLeft() {
        given("Lucas repays 250 € a month and 100 € is left") {
            updateWhatIsLeft(for: "Lucas", to: "100")
            goBack()
        }
        then("Money lent in the Income bar counts 100 € for Lucas") {
            scrollToTop()
            expect(legend("Money lent"))
            XCTAssertTrue(legend("Money lent").label.contains("€100.00"))
        }
    }

    func testFullyRepaidMoneyLentIsFoldedAway() {
        given("Emma has repaid everything") {
            updateWhatIsLeft(for: "Emma", to: "0")
            goBack()
        }
        then("she is folded under Fully repaid") {
            XCTAssertTrue(scrollUntilVisible(text("Fully repaid (1)")))
            XCTAssertFalse(text("Emma").exists)
        }
        when("I tap Fully repaid") {
            tap(text("Fully repaid (1)"))
        }
        then("her card shows All repaid") {
            expect(text("Emma"))
            expect(text("All repaid"))
        }
    }

    func testAddMoneyLent() {
        when("I add 500 € lent to Paul, repaid at 50 € a month") {
            addMoneyLent(to: "Paul", amount: "500", monthly: "50")
        }
        then("Paul is listed with 500 € left to repay") {
            XCTAssertTrue(scrollUntilVisible(text("Paul")))
            expect(text("€50.00 a month"))
        }
        and("the monthly income goes up by 50 €") {
            scrollToTop()
            expect(text("€3,200.00"))
        }
    }

    func testSaveNeedsANameAndAnAmountLent() {
        given("the New money lent form") {
            tap(button("Add"))
            pick("Add money lent")
            expect(screen("New money lent"))
        }
        then("Save is disabled until there is a name and an amount above 0") {
            XCTAssertFalse(button("Save").isEnabled)
            type("Paul", into: field("lending-name"))
            XCTAssertFalse(button("Save").isEnabled, "No amount yet")
            type("0", into: field("lending-amount"))
            XCTAssertFalse(button("Save").isEnabled, "An amount of 0")
            replace(field("lending-amount"), with: "500")
            XCTAssertTrue(button("Save").isEnabled)
        }
    }

    func testCorrectTheLatestValueFromEdit() {
        let latest = day(5, monthsAgo: 1)
        given("Lucas's latest value is 1,500 € on \(latest)") {
            openMoneyLent(to: "Lucas")
        }
        when("I tap Edit") {
            button("Edit").tap()
        }
        then("the current value of that day is shown") {
            expect(header("Current value · \(latest)"))
            XCTAssertEqual(field("lending-remaining").value as? String, "1500")
        }
        when("I change it to 1,400 and save") {
            replace(field("lending-remaining"), with: "1400")
            save()
        }
        then("that value is corrected in place, with no new history line") {
            expect(text("€1,400.00"))
            XCTAssertFalse(button(containing: today).exists)
        }
    }

    func testDeleteMoneyLent() {
        given("the Edit money lent form for Lucas") {
            openMoneyLent(to: "Lucas")
            button("Edit").tap()
        }
        when("I tap Delete this loan and confirm") {
            tap(button("Delete this loan"))
            expect(text("Its whole history goes too."))
            answer("Delete the money lent to Lucas?", with: "Delete")
        }
        then("Lucas and his history are removed") {
            expectNo(screen("Edit money lent"))
            if screen("Lucas").exists { goBack() }
            expect(text("Emma"))
            XCTAssertFalse(text("Lucas").exists)
        }
    }

    // MARK: - Steps

    func openMoneyLent(to name: String) {
        tap(text(name))
        expect(screen(name))
    }

    func updateWhatIsLeft(for name: String, to amount: String) {
        openMoneyLent(to: name)
        tap(button("Update what's left"))
        replace(field("lending-remaining"), with: amount)
        save()
        expectNo(screen("Update what's left"))
    }

    func addMoneyLent(to name: String, amount: String, monthly: String) {
        tap(button("Add"))
        pick("Add money lent")
        type(name, into: field("lending-name"))
        type(amount, into: field("lending-amount"))
        type(monthly, into: field("lending-monthly"))
        save()
        expectNo(screen("New money lent"))
    }
}

/// Feature: Money lent detail.
final class MoneyLentDetailTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Income")
    }

    private func openLucas() {
        tap(text("Lucas"))
        expect(screen("Lucas"))
    }

    func testOpenMoneyLent() {
        when("I tap Lucas's card") {
            openLucas()
        }
        then("his page shows the card, when it was lent, the repayment, a chart and the history") {
            expect(text("Already repaid"))
            expect(text("Lent on"))
            expect(text("Monthly repayment"))
            expect(text("History"))
            expect(button(containing: day(5, monthsAgo: 1)))
        }
        screenshot("03-money-lent")
    }

    func testNotEnoughHistoryForAChart() {
        given("money lent with no value recorded yet") {
            tap(button("Add"))
            pick("Add money lent")
            type("Paul", into: field("lending-name"))
            type("500", into: field("lending-amount"))
            save()
        }
        when("I open it") {
            tap(text("Paul"))
        }
        then("the chart is replaced by a hint") {
            expect(text("Update what's left from time to time to see it go down."))
        }
    }

    func testUpdateWhatIsLeft() {
        given("Lucas has 1,500 € left") {
            openLucas()
        }
        when("I tap Update what's left") {
            tap(button("Update what's left"))
        }
        then("the form is pre-filled with what was left") {
            expect(screen("Update what's left"))
            XCTAssertEqual(field("lending-remaining").value as? String, "1500")
        }
        when("I change it to 1,250 and save") {
            replace(field("lending-remaining"), with: "1250")
            save()
        }
        then("the card shows 1,250 € left to repay") {
            expect(text("€1,250.00"))
        }
        and("a history line is added for today") {
            expect(button(containing: today))
        }
    }

    func testUpdatingTwiceOnTheSameDayReplacesTheValue() {
        given("a value was recorded for Lucas today") {
            openLucas()
            tap(button("Update what's left"))
            replace(field("lending-remaining"), with: "1250")
            save()
        }
        when("I update what's left again today") {
            tap(button("Update what's left"))
            replace(field("lending-remaining"), with: "1200")
            save()
        }
        then("today's value is replaced, not duplicated") {
            expect(text("€1,200.00"))
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", today)).count, 1)
        }
    }

    func testEditOrDeleteAPastValue() {
        let latest = day(5, monthsAgo: 1)
        when("I tap the history line of \(latest)") {
            openLucas()
            tap(button(containing: latest))
        }
        then("Edit past value opens") {
            expect(screen("Edit past value"))
        }
        when("I delete it") {
            tap(button("Delete this value"))
            answer("Delete this value?", with: "Delete")
        }
        then("the line is removed and what is left falls back to the previous value") {
            expectNo(button(containing: latest))
            expect(text("€2,000.00"))
        }
    }
}

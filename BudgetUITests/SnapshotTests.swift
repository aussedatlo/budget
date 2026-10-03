import XCTest

/// Feature: Snapshot button.
final class SnapshotButtonTests: BudgetUITestCase {
    func testTheButtonShowsWhetherThisMonthIsDone() {
        given("this month's snapshot is taken")
        then("the Snapshot button shows it") {
            expect(button("Snapshot"), timeout: 10)
            XCTAssertEqual(button("Snapshot").value as? String, "Taken this month")
        }
        given("this month's snapshot is not taken") {
            launch(missedMonths: 1)
        }
        then("the Snapshot button shows it is to take") {
            expect(button("Snapshot"), timeout: 10)
            XCTAssertEqual(button("Snapshot").value as? String, "To take this month")
        }
    }

    func testOpenTheSnapshotFromAnyTab() {
        for tab in ["Budget", "Income", "Wealth", "Trends"] {
            given("I am on the \(tab) tab") {
                openTab(tab)
            }
            when("I tap Snapshot") {
                openSnapshot()
            }
            then("the snapshot opens") {
                cancel()
                expectNo(screen("Snapshot"))
            }
        }
    }
}

/// Feature: Snapshot form.
final class SnapshotFormTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openSnapshot()
    }

    func testEverythingIsPrefilledWithTheCurrentValues() {
        then("the top shows what is left, net worth and the month") {
            expect(text("Left each month"))
            expect(text("Net worth"))
            expect(text(monthName(monthsAgo: 0)))
        }
        and("each income line has its switch and amount") {
            XCTAssertEqual(field("snapshot-income-Salary").value as? String, "2500")
            XCTAssertEqual(toggle("snapshot-income-toggle-Tutoring").value as? String, "0")
            expect(text("Repaid to you"))
        }
        screenshot("07-snapshot")
        and("each charge shows its amount, largest first") {
            let rent = field("snapshot-charge-Rent")
            XCTAssertTrue(dragUntilVisible(rent))
            XCTAssertEqual(rent.value as? String, "850")
            XCTAssertTrue(dragUntilVisible(field("snapshot-charge-Electricity")))
            XCTAssertTrue(isAbove(rent, field("snapshot-charge-Electricity")))
        }
        and("each investment, the home loan and each money lent has its own section") {
            XCTAssertTrue(dragUntilVisible(header("MSCI World")))
            XCTAssertTrue(dragUntilVisible(header("Apartment")))
            XCTAssertTrue(dragUntilVisible(header("Lent to Lucas")))
        }
        and("each of those sections says when it was last recorded") {
            expect(text(containing: "Last recorded: "))
        }
    }

    func testTotalsFollowWhatIType() {
        given("1,609.02 € left each month") {
            expect(text("€1,609.02"))
        }
        when("I change Rent to 900") {
            let rent = field("snapshot-charge-Rent")
            XCTAssertTrue(dragUntilVisible(rent))
            replace(rent, with: "900")
        }
        then("what is left each month goes down by 50 €") {
            scrollToTop()
            expect(text("€1,559.02"))
        }
    }

    func testEditedValuesAreMarked() {
        let quantity = field("snapshot-quantity") // Bitcoin's, the first investment
        when("I change an investment's quantity") {
            XCTAssertTrue(dragUntilVisible(quantity))
            replace(quantity, with: "1")
        }
        then("its section shows Edited") {
            expect(header("Edited"))
        }
        when("I set it back to the value it had") {
            replace(quantity, with: "0.08")
        }
        then("Edited goes away") {
            expectNo(header("Edited"))
        }
    }

    func testCompareWithThePreviousSnapshot() {
        let previous = monthName(monthsAgo: 1)
        given("a snapshot was taken in \(previous)")
        then("the footer compares with it") {
            expect(text(containing: "Since \(previous): net worth"))
        }
    }

    func testNoMissedMonth() {
        given("the last snapshot is from this month")
        then("no question is asked and the month can't be changed") {
            XCTAssertEqual(app.alerts.count, 0)
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Month'")).count, 0)
        }
    }
}

/// Feature: Snapshot form, money fully repaid.
final class SnapshotMoneyLentTests: BudgetUITestCase {
    func testMoneyFullyRepaidIsLeftOut() {
        given("money lent to Emma is fully repaid") {
            openTab("Income")
            tap(text("Emma"))
            tap(button("Update what's left"))
            replace(field("lending-remaining"), with: "0")
            save()
            goBack()
        }
        when("I open the snapshot") {
            openSnapshot()
        }
        then("it has a section for Lucas but none for Emma") {
            XCTAssertTrue(dragUntilVisible(header("Lent to Lucas")))
            XCTAssertFalse(header("Lent to Emma").exists)
        }
    }
}

/// Feature: Saving a snapshot.
final class SavingASnapshotTests: BudgetUITestCase {
    func testSaveThisMonth() {
        given("I changed Rent to 900 and switched Tutoring on") {
            openSnapshot()
            toggle("snapshot-income-toggle-Tutoring").tap()
            let rent = field("snapshot-charge-Rent")
            XCTAssertTrue(dragUntilVisible(rent))
            replace(rent, with: "900")
        }
        when("I save") {
            save()
            expectNo(screen("Snapshot"))
        }
        then("Rent is 900 € on the Budget tab") {
            openTab("Budget")
            expect(text("€900.00"))
        }
        and("Tutoring is switched on in the Income tab") {
            openTab("Income")
            let tutoring = toggle("income-toggle-Tutoring")
            XCTAssertTrue(scrollUntilVisible(tutoring))
            XCTAssertEqual(tutoring.value as? String, "1")
        }
        and("the month is listed on the Trends tab") {
            openTab("Trends")
            expect(text(monthName(monthsAgo: 0)))
        }
    }

    func testRetakeThisMonthsSnapshot() {
        given("this month's snapshot was taken today") {
            openSnapshot()
        }
        then("the snapshot says it replaces it") {
            expect(text(containing: "Replaces the snapshot taken on \(today)"))
        }
        when("I save") {
            save()
            expectNo(screen("Snapshot"))
        }
        then("there is still one snapshot for this month") {
            openTab("Trends")
            expect(text(monthName(monthsAgo: 0)))
            XCTAssertEqual(count(of: monthName(monthsAgo: 0)), 1)
        }
    }
}

/// Feature: Leaving the snapshot.
final class LeavingTheSnapshotTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openSnapshot()
    }

    func testCancelWithoutChanges() {
        when("I cancel without changing anything") {
            cancel()
        }
        then("the snapshot closes without asking") {
            expectNo(screen("Snapshot"))
            XCTAssertFalse(button("Discard changes").exists)
        }
    }

    func testCancelWithChangesAsksFirst() {
        given("I changed Salary") {
            type("0", into: field("snapshot-income-Salary"))
        }
        when("I cancel") {
            cancel()
        }
        then("I am asked before losing the changes") {
            expect(text("Nothing in this snapshot is saved yet."))
        }
        when("I discard the changes") {
            button("Discard changes").tap()
        }
        then("the snapshot closes and nothing is saved") {
            expectNo(screen("Snapshot"))
            expect(text("Left after savings"))
            expect(text("€1,609.02"))
        }
    }

    func testANoteCountsAsAChange() {
        when("I type a note and cancel") {
            type("Bonus month", into: field(placeholder: "Note"))
            cancel()
        }
        then("I am asked before losing it") {
            expect(button("Discard changes"))
        }
    }

    func testSwipingDownIsBlockedWhileThereAreChanges() {
        given("I changed a value") {
            type("0", into: field("snapshot-income-Salary"))
        }
        when("I swipe the snapshot down") {
            screen("Snapshot").swipeDown()
        }
        then("it stays open") {
            XCTAssertFalse(waitUntilGone(screen("Snapshot"), timeout: 2))
        }
    }
}

/// Feature: Missed months.
final class MissedMonthsTests: BudgetUITestCase {
    func testOneMonthWasSkipped() {
        let missed = monthName(monthsAgo: 1)
        given("there is no snapshot for \(missed)") {
            launch(missedMonths: 1)
        }
        when("I open the snapshot") {
            openTab("Trends")
            tap(button("Take a snapshot"))
        }
        then("I am asked which month to do") {
            expect(app.alerts["No snapshot for \(missed)"])
            expect(text(containing: "Catch up on a missing month, or go for \(monthName(monthsAgo: 0))?"))
        }
        when("I pick \(missed) and save") {
            app.alerts.buttons[missed].tap()
            expect(screen("Snapshot"))
            save()
        }
        then("\(missed) is listed on the Trends tab") {
            expect(text(missed))
        }
    }

    func testTwoMonthsWereSkipped() {
        let older = monthName(monthsAgo: 2)
        let newer = monthName(monthsAgo: 1)
        let current = monthName(monthsAgo: 0)
        given("there is no snapshot for \(older) and \(newer)") {
            launch(missedMonths: 2)
        }
        when("I open the snapshot") {
            openTab("Trends")
            tap(button("Take a snapshot"))
        }
        then("I am asked about both months and the current one") {
            let alert = app.alerts["No snapshot for 2 months"]
            expect(alert)
            for month in [older, newer, current] {
                XCTAssertTrue(alert.buttons[month].exists, "\(month) should be offered")
            }
        }
        when("I catch up on \(older) and open the snapshot again") {
            app.alerts.buttons[older].tap()
            expect(screen("Snapshot"))
            save()
            expect(text(older))
            tap(button("Take a snapshot"))
        }
        then("only \(newer) is still offered") {
            let alert = app.alerts["No snapshot for \(newer)"]
            expect(alert)
            XCTAssertFalse(alert.buttons[older].exists)
            XCTAssertTrue(alert.buttons[current].exists)
        }
    }

    func testManyMonthsWereSkipped() {
        given("5 months have no snapshot") {
            launch(missedMonths: 5)
        }
        when("I open the snapshot") {
            openSnapshot()
        }
        then("the 3 most recent of them and the current month are offered") {
            let alert = app.alerts["No snapshot for 5 months"]
            expect(alert)
            for monthsAgo in 0...3 {
                XCTAssertTrue(alert.buttons[monthName(monthsAgo: monthsAgo)].exists)
            }
            for monthsAgo in 4...5 {
                XCTAssertFalse(alert.buttons[monthName(monthsAgo: monthsAgo)].exists)
            }
        }
        and("older months are at the top of the snapshot") {
            expect(text(containing: "Older months are listed there too."))
        }
    }

    func testAPastMonthDoesNotChangeTheCurrentState() {
        let missed = monthName(monthsAgo: 1)
        given("I catch up on \(missed)") {
            launch(missedMonths: 1)
            openSnapshot()
            app.alerts.buttons[missed].tap()
        }
        then("the snapshot says to set the values to what they were then") {
            expect(text(containing: "set them to what they were in \(missed)"))
            expect(text(containing: "saved in this past month only"))
        }
        when("I change Rent to 800 and save") {
            let rent = field("snapshot-charge-Rent")
            XCTAssertTrue(dragUntilVisible(rent))
            replace(rent, with: "800")
            save()
            expectNo(screen("Snapshot"))
        }
        then("the Budget tab still shows Rent at 850 €") {
            openTab("Budget")
            expect(text("€850.00"))
            XCTAssertFalse(text("€800.00").exists)
        }
        and("the \(missed) snapshot has Rent at 800 €") {
            openTab("Trends")
            tap(text(missed))
            XCTAssertTrue(dragUntilVisible(text("€800.00")))
        }
    }
}

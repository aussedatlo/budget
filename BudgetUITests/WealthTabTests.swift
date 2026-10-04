import XCTest

/// Feature: Wealth overview.
/// Investments by default; net worth (investments + home equity + money lent)
/// when there is a home loan or money owed.
final class WealthOverviewTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Wealth")
    }

    func testSeeInvestments() {
        given("the demo data")
        then("the title is Wealth and the header shows the investments value") {
            expect(screen("Wealth"), timeout: 10)
            expect(text("Investments value"))
            expect(text(containing: "Invested €"))
        }
        and("investments are listed by name with their ticker and type") {
            XCTAssertTrue(isAbove(text("Bitcoin"), text("Gold coins")))
            XCTAssertTrue(isAbove(text("Gold coins"), text("MSCI World")))
            expect(text("CW8 · ETF"))
        }
        and("the home loan is not listed") {
            XCTAssertFalse(text("Apartment").exists)
        }
        screenshot("04-wealth")
    }

    func testAGrowingSeedlingNextToTheTotal() {
        given("the demo data")
        then("a seedling grows and sways next to Investments value") {
            let seedling = app.descendants(matching: .any)["seedling"].firstMatch
            expect(seedling, timeout: 10)
            XCTAssertLessThanOrEqual(seedling.frame.maxX, text("Investments value").frame.minX)
        }
    }

    func testSwitchToNetWorth() {
        when("I tap the bank button next to Investments value") {
            tap(button("Show net worth"))
        }
        then("the header shows net worth with what it's made of") {
            expect(text("Net worth"))
            expect(button("Show investments only"))
            expect(text(containing: "Home equity €"))
            expect(text(containing: "Money lent €"))
            expect(text(containing: "Investments €"))
        }
        and("the home loan is listed above the investments") {
            expect(text("Apartment"))
            XCTAssertTrue(isAbove(text("Apartment"), text("Bitcoin")))
        }
        screenshot("05-net-worth")
    }

    func testSwitchBackToInvestments() {
        given("net worth is shown") {
            tap(button("Show net worth"))
            expect(text("Net worth"))
        }
        when("I tap the filled bank button") {
            tap(button("Show investments only"))
        }
        then("the header shows Investments value and the bank button is outlined again") {
            expect(text("Investments value"))
            expect(button("Show net worth"))
        }
    }

    private var total: XCUIElement { app.staticTexts["wealth-total"] }

    func testHideAnInvestmentFromTheTotal() {
        given("the demo data")
        expect(total, timeout: 10)
        let before = total.label
        when("I tap the eye on Bitcoin") {
            tap(button("Hide Bitcoin"))
        }
        then("Bitcoin stays listed with a crossed-out eye") {
            expect(button("Show Bitcoin"))
            expect(text("Bitcoin"))
        }
        and("the total leaves Bitcoin out and a chip says 1 hidden") {
            expect(text("1 hidden"))
            XCTAssertNotEqual(total.label, before)
        }
    }

    func testShowAHiddenInvestmentAgain() {
        expect(total, timeout: 10)
        let before = total.label
        given("Bitcoin is hidden") {
            tap(button("Hide Bitcoin"))
            expect(text("1 hidden"))
        }
        when("I tap its crossed-out eye") {
            tap(button("Show Bitcoin"))
        }
        then("Bitcoin counts in the total again and the hidden chip goes away") {
            expectNo(text("1 hidden"))
            expect(button("Hide Bitcoin"))
            XCTAssertEqual(total.label, before)
        }
    }
}

/// Feature: Investments.
final class InvestmentsTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Wealth")
    }

    private func openNewInvestment() {
        tap(button("Add"))
        pick("Add investment")
        expect(screen("New investment"))
    }

    func testAddAnInvestmentWithItsValueToday() {
        when("I add Tesla, worth 10,000 € today, with 9,000 € invested") {
            openNewInvestment()
            type("Tesla", into: field(placeholder: "Name (e.g. MSCI World)"))
            type("TSLA", into: field(placeholder: "Ticker (optional)"))
            type("10000", into: field("snapshot-value"))
            type("9000", into: field("snapshot-invested"))
            save()
        }
        then("Tesla is listed with its value and gain") {
            XCTAssertTrue(scrollUntilVisible(text("Tesla")))
            expect(text("TSLA · ETF"))
            expect(text("€10,000.00"))
            expect(text("+11.11%"))
        }
    }

    func testTrackQuantityTimesUnitPrice() {
        given("the New investment form") {
            openNewInvestment()
        }
        when("I track quantity × unit price: 3 at 150 €") {
            flip(toggle("Quantity × unit price"))
            type("3", into: field("snapshot-quantity"))
            type("150", into: field("snapshot-unit-price"))
        }
        then("the value is 450 €") {
            expect(anything(containing: "€450.00"))
        }
    }

    func testSaveNeedsOnlyAName() {
        given("the New investment form with an empty name") {
            openNewInvestment()
            XCTAssertFalse(button("Save").isEnabled)
        }
        when("I enter a name with no value and save") {
            type("Cash", into: field(placeholder: "Name (e.g. MSCI World)"))
            XCTAssertTrue(button("Save").isEnabled)
            save()
        }
        then("the investment is listed") {
            XCTAssertTrue(scrollUntilVisible(text("Cash")))
        }
    }

    func testEditAnInvestment() {
        when("I choose Edit in MSCI World's menu") {
            choose("Edit", inMenuOf: text("MSCI World"))
        }
        then("Edit investment opens without today's values") {
            expect(screen("Edit investment"))
            XCTAssertFalse(header("Today").exists)
        }
        when("I set its monthly savings to 150 € and save") {
            type("150", into: field("monthly-contribution"))
            save()
        }
        then("the Budget tab sets 150 € aside for it") {
            openTab("Budget")
            XCTAssertTrue(scrollUntilVisible(text("MSCI World")))
            expect(text("€150.00"))
        }
    }

    func testDeleteAnInvestment() {
        when("I choose Delete in Bitcoin's menu and confirm") {
            choose("Delete", inMenuOf: text("Bitcoin"))
            expect(text("Its whole history goes too."))
            answer("Delete Bitcoin?", with: "Delete")
        }
        then("Bitcoin and its history are removed") {
            expectNo(text("Bitcoin"))
        }
    }
}

/// Feature: Investment detail.
final class InvestmentDetailTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Wealth")
    }

    private func openMSCIWorld() {
        tap(text("MSCI World"))
        expect(screen("MSCI World"))
    }

    func testOpenAnInvestment() {
        when("I tap MSCI World") {
            openMSCIWorld()
        }
        then("its page shows the value, what was invested and the gain") {
            expect(text("€10,290.00"))
            expect(text(containing: "Invested €"))
        }
        and("tiles for quantity, unit price, invested so far and the last update") {
            expect(text("Quantity"))
            expect(text("Unit price"))
            expect(text("Invested so far"))
            expect(text("Updated"))
        }
        and("the history") {
            expect(text("History"))
            expect(button("Update values"))
        }
    }

    func testUpdateValuesStartingFromTheCurrentOnes() {
        given("MSCI World's latest values are 21 × 490 €") {
            openMSCIWorld()
        }
        when("I tap Update values") {
            tap(button("Update values"))
            expect(screen("Update values"))
        }
        then("the quantity and unit price are pre-filled") {
            XCTAssertEqual(field("snapshot-quantity").value as? String, "21")
            XCTAssertEqual(field("snapshot-unit-price").value as? String, "490")
            expect(text("Pre-filled with the current values: just change what moved."))
        }
    }

    func testUpdatingTwiceOnTheSameDayCorrectsTheValues() {
        given("values were recorded for MSCI World today") {
            openMSCIWorld()
        }
        let linesToday = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", today))
        let before = linesToday.count
        when("I update the values again today") {
            tap(button("Update values"))
            replace(field("snapshot-quantity"), with: "22")
            save()
        }
        then("today's values are replaced, not duplicated") {
            expect(text("€10,780.00"))
            XCTAssertEqual(linesToday.count, before)
        }
    }

    func testEditOrDeletePastValues() {
        when("I tap today's history line") {
            openMSCIWorld()
            tap(button(containing: today))
        }
        then("Edit past values opens") {
            expect(screen("Edit past values"))
        }
        when("I delete these values") {
            tap(button("Delete these values"))
            answer("Delete these values?", with: "Delete")
        }
        then("the current value falls back to the previous one") {
            expect(text("€9,680.00"))
        }
    }
}

/// Feature: Home loan.
final class HomeLoanTests: BudgetUITestCase {
    override func setUp() {
        super.setUp()
        openTab("Wealth")
        tap(button("Show net worth"))
    }

    private func openApartment() {
        tap(text("Apartment"))
        expect(screen("Apartment"))
    }

    func testAddAHomeLoan() {
        when("I add a home loan of 200,000 €, 160,000 € left, for a home worth 250,000 €") {
            tap(button("Add"))
            pick("Add home loan")
            expect(screen("New home loan"))
            XCTAssertEqual(field(placeholder: "Name").value as? String, "Home")
            type("200000", into: field("loan-borrowed"))
            type("160000", into: field("loan-remaining"))
            type("250000", into: field("loan-home-value"))
            save()
        }
        then("it is listed with 90,000 € of equity (36%)") {
            expect(text("36% equity"))
            expect(text("€90,000.00"))
        }
    }

    func testSaveNeedsANameAndAnAmountBorrowed() {
        given("the New home loan form") {
            tap(button("Add"))
            pick("Add home loan")
        }
        then("Save is disabled until an amount borrowed above 0 is entered") {
            XCTAssertFalse(button("Save").isEnabled)
            type("0", into: field("loan-borrowed"))
            XCTAssertFalse(button("Save").isEnabled, "An amount of 0")
            replace(field("loan-borrowed"), with: "200000")
            XCTAssertTrue(button("Save").isEnabled)
        }
    }

    func testOpenTheHomeLoan() {
        when("I tap the Apartment card") {
            openApartment()
        }
        then("its page shows what is repaid, what is left, the amount borrowed and the home value") {
            expect(text("Already repaid"))
            expect(text("Left to repay"))
            expect(text("Borrowed"))
            expect(text("Home value"))
            expect(text("History"))
        }
    }

    func testUpdateValuesStartingFromTheCurrentOnes() {
        when("I tap Update values on the loan page") {
            openApartment()
            tap(button("Update values"))
        }
        then("what is left is pre-filled with the latest value") {
            XCTAssertEqual(field("loan-remaining").value as? String, "135040")
            expect(text("Already repaid"))
            expect(text("Ours"))
        }
        when("I change it to 134,000 and save") {
            replace(field("loan-remaining"), with: "134000")
            save()
        }
        then("the page shows 134,000 € left to repay") {
            expect(text("€134,000.00"))
        }
    }

    func testCorrectTheLatestValuesFromEdit() {
        given("the Apartment page") {
            openApartment()
        }
        when("I tap Edit") {
            button("Edit").tap()
        }
        then("the latest values are shown with their date") {
            expect(header("Current values · \(today)"))
        }
        when("I change what is left to 150,000 and save") {
            replace(field("loan-remaining"), with: "150000")
            save()
        }
        then("the page shows 150,000 € left to repay") {
            expect(text("€150,000.00"))
        }
        screenshot("06-home-loan")
    }

    func testEditOrDeletePastValues() {
        when("I tap today's history line") {
            openApartment()
            tap(button(containing: today))
        }
        then("Edit past values opens") {
            expect(screen("Edit past values"))
        }
        when("I delete these values") {
            tap(button("Delete these values"))
            answer("Delete these values?", with: "Delete")
        }
        then("what is left falls back to the previous values") {
            expect(text("€148,790.00"))
        }
    }

    func testDeleteTheHomeLoan() {
        given("the Edit loan form for Apartment") {
            openApartment()
            button("Edit").tap()
        }
        when("I tap Delete this loan and confirm") {
            tap(button("Delete this loan"))
            expect(text("Its whole history goes too."))
            answer("Delete Apartment?", with: "Delete")
        }
        then("the loan is removed and home equity leaves net worth") {
            expectNo(screen("Edit loan"))
            if screen("Apartment").exists { goBack() }
            expectNo(text("Apartment"))
            XCTAssertFalse(text(containing: "Home equity").exists)
        }
    }
}

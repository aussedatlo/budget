package com.example.budget.core

import kotlinx.datetime.TimeZone
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.time.Clock
import kotlin.time.Instant

/** A fixed "now", in UTC, for every test. */
internal object TestClock : Clock {
    var instant: Instant = Instant.parse("2026-10-15T09:30:00Z")
    override fun now(): Instant = instant
}

internal fun day(text: String): Instant = Instant.parse("${text}T12:00:00Z")

internal fun useTestCalendar() {
    BudgetCalendar.timeZone = TimeZone.UTC
    TestClock.instant = Instant.parse("2026-10-15T09:30:00Z")
    BudgetCalendar.clock = TestClock
}

class CalendarTest {
    @BeforeTest fun setUp() = useTestCalendar()

    @Test fun monthsBetweenCountsCalendarMonths() {
        assertEquals(0, BudgetCalendar.monthsBetween(day("2026-03-01"), day("2026-03-31")))
        assertEquals(1, BudgetCalendar.monthsBetween(day("2026-03-31"), day("2026-04-01")))
        assertEquals(14, BudgetCalendar.monthsBetween(day("2025-01-20"), day("2026-03-02")))
        assertEquals(0, BudgetCalendar.monthsBetween(day("2026-05-01"), day("2026-03-01")))
    }

    @Test fun monthBoundaries() {
        assertEquals(Instant.parse("2026-02-01T00:00:00Z"), BudgetCalendar.startOfMonth(day("2026-02-14")))
        assertEquals(Instant.parse("2026-02-28T23:59:59Z"), BudgetCalendar.endOfMonth(day("2026-02-14")))
        assertEquals(Instant.parse("2026-02-14T23:59:59Z"), BudgetCalendar.endOfDay(day("2026-02-14")))
        assertEquals(Instant.parse("2025-12-01T00:00:00Z"), BudgetCalendar.addMonths(day("2026-02-14"), -2))
        assertTrue(BudgetCalendar.isSameMonth(day("2026-02-01"), day("2026-02-28")))
        assertFalse(BudgetCalendar.isSameMonth(day("2026-02-01"), day("2025-02-01")))
    }
}

class InvestmentTest {
    @BeforeTest fun setUp() = useTestCalendar()

    private fun investment(vararg history: ValueSnapshot, monthly: Double = 100.0) =
        Investment(name = "Savings", kind = InvestmentKind.SAVINGS, monthlyContribution = monthly, history = history.toList())

    @Test fun latestValuesAndGain() {
        val i = investment(
            ValueSnapshot(date = day("2026-01-10"), value = 1_000.0, invested = 900.0),
            ValueSnapshot(date = day("2026-03-10"), value = 1_300.0, invested = 1_100.0),
        )
        assertEquals(1_300.0, i.currentValue)
        assertEquals(200.0, i.gain)
        assertEquals(200.0 / 1_100.0, i.gainRatio)
        assertEquals(1_000.0, i.snapshotAt(day("2026-02-01"))?.value)
        assertNull(i.snapshotAt(day("2025-12-01")))
    }

    @Test fun investedForSnapshotAddsThePlanForEachMonth() {
        val i = investment(ValueSnapshot(date = day("2026-07-20"), value = 1_000.0, invested = 1_000.0))
        // July -> October: three months of 100
        assertEquals(1_300.0, i.investedForSnapshot(day("2026-10-15"), savingIncluded = true))
        assertEquals(1_200.0, i.investedForSnapshot(day("2026-10-15"), savingIncluded = false))
    }

    @Test fun retakingAMonthStartsFromTheMonthBefore() {
        val i = investment(
            ValueSnapshot(date = day("2026-09-20"), value = 1_000.0, invested = 1_000.0),
            ValueSnapshot(date = day("2026-10-02"), value = 1_100.0, invested = 1_100.0),
        )
        assertEquals(1_100.0, i.investedForSnapshot(day("2026-10-15"), savingIncluded = true))
        assertEquals(1_000.0, i.investedForSnapshot(day("2026-10-15"), savingIncluded = false))
    }

    @Test fun anAmountFixedByHandThatMonthIsKept() {
        val i = investment(
            ValueSnapshot(date = day("2026-09-20"), value = 1_000.0, invested = 1_000.0),
            ValueSnapshot(date = day("2026-10-02"), value = 1_500.0, invested = 1_450.0),
        )
        assertEquals(1_450.0, i.investedForSnapshot(day("2026-10-15"), savingIncluded = true))
    }

    @Test fun withoutAnEarlierMonthTheLatestAmountIsUsed() {
        val i = investment(ValueSnapshot(date = day("2026-10-02"), value = 500.0, invested = 480.0))
        assertEquals(480.0, i.investedForSnapshot(day("2026-10-15"), savingIncluded = true))
        assertEquals(0.0, investment().investedForSnapshot(day("2026-10-15"), savingIncluded = true))
    }

    @Test fun savingsPerMonthCountOnlyMoneyPutIn() {
        val i = investment(
            ValueSnapshot(date = day("2026-08-20"), value = 1_000.0, invested = 1_000.0),
            ValueSnapshot(date = day("2026-09-20"), value = 900.0, invested = 1_200.0),
            ValueSnapshot(date = day("2026-10-10"), value = 2_000.0, invested = 1_200.0),
        )
        val points = Savings.monthly(listOf(i), months = 12, now = day("2026-10-15"))
        assertEquals(listOf(SavingsPoint(Instant.parse("2026-09-01T00:00:00Z"), "Savings", 200.0)), points)
    }

    @Test fun historyHasOnePointPerDay() {
        val a = investment(
            ValueSnapshot(date = day("2026-01-10"), value = 100.0, invested = 100.0),
            ValueSnapshot(date = day("2026-02-10"), value = 150.0, invested = 120.0),
        )
        val b = investment(ValueSnapshot(date = day("2026-02-10"), value = 50.0, invested = 40.0))
        val points = History.points(listOf(a, b))
        assertEquals(2, points.size)
        assertEquals(100.0, points[0].value)
        assertEquals(200.0, points[1].value)
        assertEquals(160.0, points[1].invested)
    }
}

class IncomeAndLoansTest {
    @BeforeTest fun setUp() = useTestCalendar()

    @Test fun lendingRepaymentsNeverExceedWhatIsLeft() {
        val lending = Lending(
            name = "Lucas", lent = 3_000.0, date = day("2026-01-03"), monthlyRepayment = 250.0,
            history = listOf(LendingSnapshot(date = day("2026-09-05"), remaining = 100.0)),
        )
        assertEquals(100.0, lending.expectedThisMonth)
        assertEquals(2_900.0, lending.repaid)
        assertEquals(0.0, lending.remainingAt(day("2025-12-01")))
        assertEquals(3_000.0, lending.remainingAt(day("2026-02-01")))
        assertFalse(lending.isSettled)
        assertTrue(lending.copy(history = lending.history + LendingSnapshot(date = day("2026-10-05"))).isSettled)
    }

    @Test fun incomeCountsActiveLinesAndRepayments() {
        val totals = IncomeTotals(
            listOf(
                IncomeSource(title = "Salary", amount = 2_000.0),
                IncomeSource(title = "Tutoring", amount = 150.0, isActive = false),
            ),
            listOf(Lending(name = "Lucas", lent = 1_000.0, monthlyRepayment = 200.0)),
        )
        assertEquals(2_000.0, totals.sources)
        assertEquals(200.0, totals.repayments)
        assertEquals(2_200.0, totals.total)
    }

    @Test fun loanEquity() {
        val loan = Loan(
            name = "Apartment", borrowed = 200_000.0,
            history = listOf(LoanSnapshot(date = day("2026-06-01"), remaining = 150_000.0, homeValue = 250_000.0)),
        )
        assertEquals(100_000.0, loan.equity)
        assertEquals(0.4, loan.equityRatio)
        assertEquals(0.25, loan.repaidRatio)
        assertEquals(200_000.0, loan.copy(history = emptyList()).remaining)
    }
}

class DemoDataTest {
    @BeforeTest fun setUp() = useTestCalendar()

    @Test fun budgetOfTheDemoData() {
        val budget = DemoData.state().budget
        // 2 500 salary + 400 freelance + 250 repaid by Lucas
        assertEquals(3_150.0, budget.income)
        assertEquals(1_040.98, budget.charges, 0.001)
        assertEquals(500.0, budget.savings)
        assertEquals(1_609.02, budget.left, 0.001)
        assertEquals("Left after savings", budget.title)
    }

    @Test fun overBudget() {
        val state = DemoData.state().let { it.copy(charges = it.charges + FixedCharge(title = "Big", amount = 5_000.0)) }
        assertEquals("Over budget", state.budget.title)
        assertTrue(state.budget.isOverBudget)
    }

    @Test fun oneSnapshotPerMonthOverAYear() {
        val state = DemoData.state()
        assertEquals(12, state.snapshots.size)
        assertTrue(Snapshot.isTakenThisMonth(state.snapshots))
        assertEquals(emptyList(), Snapshot.missingMonths(state.snapshots))
    }

    @Test fun missedMonthsAreListedToCatchUp() {
        val state = DemoData.state(missedMonths = 2)
        assertEquals(9, state.snapshots.size)
        assertFalse(Snapshot.isTakenThisMonth(state.snapshots))
        assertEquals(
            listOf(Instant.parse("2026-08-01T00:00:00Z"), Instant.parse("2026-09-01T00:00:00Z")),
            Snapshot.missingMonths(state.snapshots),
        )
        assertEquals(Instant.parse("2026-08-31T23:59:59Z"), Snapshot.dateFor(Instant.parse("2026-08-01T00:00:00Z")))
        assertEquals(TestClock.instant, Snapshot.dateFor(Instant.parse("2026-10-01T00:00:00Z")))
    }

    @Test fun netWorthAddsHomeEquityAndMoneyLent() {
        val state = DemoData.state()
        val wealth = state.wealth
        val lent = 1_500.0 + 400.0
        val home = state.loans.single()
        assertEquals(wealth.investments + home.equity + lent, wealth.netWorth, 0.001)
        assertTrue(Wealth.points(state.investments, state.loans, state.lendings).size > 12)
    }
}

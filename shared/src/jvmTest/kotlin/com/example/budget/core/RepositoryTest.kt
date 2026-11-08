package com.example.budget.core

import com.example.budget.core.data.BudgetRepository
import com.example.budget.core.data.BudgetStore
import com.example.budget.core.data.DatabaseFactory
import com.example.budget.core.data.SnapshotRequest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.time.Instant

class RepositoryTest {
    private lateinit var repo: BudgetRepository

    @BeforeTest fun setUp() {
        useTestCalendar()
        repo = BudgetRepository(DatabaseFactory().create(inMemory = true))
    }

    @Test fun chargesAreAddedEditedAndDeleted() {
        var told = 0
        repo.addListener { told++ }
        val id = repo.saveCharge(FixedCharge(title = "Phone", amount = 15.0, category = ChargeCategory.UTILITIES))
        repo.saveCharge(FixedCharge(title = "Rent", amount = 850.0, category = ChargeCategory.HOUSING))
        assertEquals(listOf("Rent", "Phone"), repo.current.charges.map { it.title })

        repo.saveCharge(repo.current.charge(id)!!.copy(amount = 900.0))
        assertEquals(listOf("Phone", "Rent"), repo.current.charges.map { it.title })

        repo.deleteCharge(id)
        assertEquals(listOf("Rent"), repo.current.charges.map { it.title })
        assertEquals(4, told)
    }

    @Test fun demoDataRoundTrips() {
        val demo = BudgetStore.openDemo(DatabaseFactory())
        val expected = DemoData.state()
        val state = demo.current
        assertEquals(expected.budget.left, state.budget.left, 0.001)
        assertEquals(expected.wealth.netWorth, state.wealth.netWorth, 0.001)
        assertEquals(expected.snapshots.map { it.chargeLines }, state.snapshots.map { it.chargeLines })
        assertEquals(listOf("Salary", "Freelance", "Tutoring"), state.incomeSources.map { it.title })
        assertEquals(listOf("Bitcoin", "Gold coins", "MSCI World", "Savings account"), state.investments.map { it.name })
        assertEquals(expected.investments.sumOf { it.history.size }, state.investments.sumOf { it.history.size })
    }

    @Test fun deletingAParentDeletesItsHistory() {
        val id = repo.saveInvestment(
            Investment(name = "ETF", history = listOf(ValueSnapshot(date = day("2026-01-01"), value = 1.0))),
        )
        repo.saveValueSnapshot(id, ValueSnapshot(date = day("2026-02-01"), value = 2.0))
        assertEquals(2, repo.current.investment(id)!!.history.size)
        repo.deleteInvestment(id)
        repo.saveInvestment(Investment(name = "Other"))
        assertTrue(repo.current.investments.single().history.isEmpty())
    }

    @Test fun takingTheCurrentMonthUpdatesTheCurrentState() {
        val salary = repo.saveIncomeSource(IncomeSource(title = "Salary", amount = 2_000.0))
        val rent = repo.saveCharge(FixedCharge(title = "Rent", amount = 800.0, category = ChargeCategory.HOUSING))
        val etf = repo.saveInvestment(
            Investment(name = "ETF", monthlyContribution = 100.0,
                history = listOf(ValueSnapshot(date = day("2026-09-20"), value = 1_000.0, invested = 1_000.0))),
        )
        repo.saveLending(Lending(name = "Lucas", lent = 1_000.0, date = day("2026-01-01"), monthlyRepayment = 50.0))

        val start = SnapshotRequest.from(repo.current, TestClock.instant)
        val request = start.copy(
            incomeSources = listOf(SnapshotRequest.SourceEntry(salary, 2_100.0, true)),
            charges = listOf(SnapshotRequest.ChargeEntry(rent, 820.0)),
            investments = listOf(SnapshotRequest.InvestmentEntry(etf, 1_250.0)),
        )
        val plan = request.plan(repo.current)
        assertEquals(2_150.0, plan.income)
        assertEquals(2_150.0 - 820.0 - 100.0, plan.left)
        repo.takeSnapshot(request)

        val state = repo.current
        assertEquals(2_100.0, state.incomeSource(salary)!!.amount)
        assertEquals(820.0, state.charge(rent)!!.amount)
        val snapshot = state.snapshots.single()
        assertEquals(TestClock.instant, snapshot.date)
        assertEquals(listOf("Salary", "Repaid by Lucas"), snapshot.incomeLines.map { it.title })
        assertEquals(listOf(SnapshotLine("Rent", 820.0, "housing")), snapshot.chargeLines)
        assertEquals(100.0, snapshot.savings)
        val latest = state.investment(etf)!!.latest!!
        assertEquals(1_250.0, latest.value)
        assertEquals(1_100.0, latest.invested)

        // Taking it again replaces it, and the saving isn't added twice
        repo.takeSnapshot(SnapshotRequest.from(repo.current, TestClock.instant).copy(note = "again"))
        assertEquals("again", repo.current.snapshots.single().note)
        assertEquals(2, repo.current.investment(etf)!!.history.size)
        assertEquals(1_100.0, repo.current.investment(etf)!!.latest!!.invested)
    }

    @Test fun aPastMonthKeepsItsBudgetToItself() {
        val salary = repo.saveIncomeSource(IncomeSource(title = "Salary", amount = 2_000.0))
        val august = Instant.parse("2026-08-01T00:00:00Z")
        repo.takeSnapshot(
            SnapshotRequest.from(repo.current, august).copy(
                incomeSources = listOf(SnapshotRequest.SourceEntry(salary, 1_500.0, true)),
            ),
        )
        assertEquals(2_000.0, repo.current.incomeSource(salary)!!.amount)
        val snapshot = repo.current.snapshots.single()
        assertEquals(1_500.0, snapshot.income)
        assertEquals(Instant.parse("2026-08-31T23:59:59Z"), snapshot.date)
    }

    @Test fun deletingASnapshotCanRemoveTheValuesOfItsMonth() {
        val etf = repo.saveInvestment(Investment(name = "ETF"))
        repo.saveValueSnapshot(etf, ValueSnapshot(date = day("2026-09-10"), value = 10.0))
        repo.takeSnapshot(SnapshotRequest.from(repo.current, TestClock.instant).copy(
            investments = listOf(SnapshotRequest.InvestmentEntry(etf, 20.0)),
        ))
        assertEquals(2, repo.current.investment(etf)!!.history.size)

        val keep = repo.current.snapshots.single().id
        repo.deleteSnapshot(keep, withValues = false)
        assertEquals(2, repo.current.investment(etf)!!.history.size)

        repo.takeSnapshot(SnapshotRequest.from(repo.current, TestClock.instant))
        repo.deleteSnapshot(repo.current.snapshots.single().id, withValues = true)
        assertTrue(repo.current.snapshots.isEmpty())
        assertEquals(listOf(10.0), repo.current.investment(etf)!!.history.map { it.value })
    }

    @Test fun metaValues() {
        assertNull(repo.meta("x"))
        repo.setMeta("x", "1")
        assertNotNull(repo.meta("x"))
    }
}

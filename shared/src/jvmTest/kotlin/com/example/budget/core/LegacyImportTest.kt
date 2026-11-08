package com.example.budget.core

import com.example.budget.core.data.BudgetRepository
import com.example.budget.core.data.DatabaseFactory
import com.example.budget.core.data.LegacyImport
import com.example.budget.core.data.LegacyRows
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.time.Instant

/** Rows as the iOS app reads them from the SwiftData (Core Data) store. */
private class FakeRows(private val tables: Map<String, List<Map<String, String>>>) : LegacyRows {
    override fun rows(table: String) = tables[table].orEmpty()
}

/** Seconds since 1 January 2001, as Core Data stores dates. */
private fun coreData(instant: Instant) = ((instant.toEpochMilliseconds() / 1000.0) - 978_307_200.0).toString()

class LegacyImportTest {
    private lateinit var repo: BudgetRepository

    @BeforeTest fun setUp() {
        useTestCalendar()
        repo = BudgetRepository(DatabaseFactory().create(inMemory = true))
    }

    private val rows = FakeRows(
        mapOf(
            "ZFIXEDCHARGE" to listOf(
                mapOf("Z_PK" to "1", "ZTITLE" to "Netflix", "ZAMOUNT" to "13.49", "ZCATEGORYRAW" to "subscriptions", "ZDAYOFMONTH" to "15", "ZEMOJI" to ""),
                mapOf("Z_PK" to "2", "ZTITLE" to "Rent", "ZAMOUNT" to "850.0", "ZCATEGORYRAW" to "housing", "ZDAYOFMONTH" to "5", "ZEMOJI" to "🏠"),
            ),
            "ZINCOMESOURCE" to listOf(
                mapOf("Z_PK" to "1", "ZTITLE" to "Freelance", "ZAMOUNT" to "400", "ZEMOJI" to "💼", "ZISACTIVE" to "0", "ZCREATEDAT" to coreData(day("2026-02-01"))),
                mapOf("Z_PK" to "2", "ZTITLE" to "Salary", "ZAMOUNT" to "2500", "ZEMOJI" to "🏢", "ZISACTIVE" to "1", "ZCREATEDAT" to coreData(day("2026-01-01"))),
            ),
            "ZINVESTMENT" to listOf(
                mapOf("Z_PK" to "7", "ZNAME" to "Gold coins", "ZTICKER" to "XAU", "ZKINDRAW" to "Precious metal", "ZEMOJI" to "", "ZCREATEDAT" to coreData(day("2026-01-01")), "ZMONTHLYCONTRIBUTION" to "300"),
            ),
            "ZVALUESNAPSHOT" to listOf(
                mapOf("Z_PK" to "1", "ZINVESTMENT" to "7", "ZDATE" to coreData(day("2026-09-20")), "ZVALUE" to "1980.5", "ZINVESTED" to "1800", "ZQUANTITY" to "4.5", "ZUNITPRICE" to "440.111", "ZNOTE" to "first"),
                mapOf("Z_PK" to "2", "ZINVESTMENT" to "7", "ZDATE" to coreData(day("2026-10-02")), "ZVALUE" to "2100", "ZINVESTED" to "2100"),
            ),
            "ZLOAN" to listOf(mapOf("Z_PK" to "3", "ZNAME" to "Apartment", "ZEMOJI" to "🏠", "ZBORROWED" to "240000", "ZCREATEDAT" to coreData(day("2022-01-01")))),
            "ZLOANSNAPSHOT" to listOf(mapOf("Z_PK" to "1", "ZLOAN" to "3", "ZDATE" to coreData(day("2026-06-10")), "ZREMAINING" to "190000", "ZHOMEVALUE" to "280000")),
            "ZLENDING" to listOf(mapOf("Z_PK" to "1", "ZNAME" to "Lucas", "ZEMOJI" to "🚗", "ZLENT" to "3000", "ZDATE" to coreData(day("2026-03-03")), "ZMONTHLYREPAYMENT" to "250", "ZNOTE" to "")),
            "ZLENDINGSNAPSHOT" to listOf(mapOf("Z_PK" to "1", "ZLENDING" to "1", "ZDATE" to coreData(day("2026-09-05")), "ZREMAINING" to "1500")),
            "ZSNAPSHOT" to listOf(
                mapOf(
                    "Z_PK" to "1", "ZDATE" to coreData(day("2026-09-20")), "ZNOTE" to "September", "ZMAININCOME" to "0",
                    "ZOTHERINCOME" to "2900", "ZREPAYMENTS" to "250", "ZCHARGES" to "863.49", "ZSAVINGS" to "300",
                    "ZCHARGELINESDATA" to """[{"title":"Rent","amount":850,"category":"housing"},{"title":"Netflix","amount":13.49,"category":"subscriptions"}]""",
                    "ZINCOMELINESDATA" to """[{"title":"Salary","amount":2500,"category":""},{"title":"Repaid by Lucas","amount":250,"category":""}]""",
                ),
            ),
        ),
    )

    @Test fun everythingIsImportedWithItsHistory() {
        LegacyImport.run(repo, rows)
        val state = repo.current
        assertEquals(listOf("Rent", "Netflix"), state.charges.map { it.title })
        assertEquals(ChargeCategory.SUBSCRIPTIONS, state.charges[1].category)
        assertEquals(listOf("Salary", "Freelance"), state.incomeSources.map { it.title })
        assertEquals(false, state.incomeSources[1].isActive)
        val gold = state.investments.single()
        assertEquals(InvestmentKind.METAL, gold.kind)
        assertEquals(300.0, gold.monthlyContribution)
        assertEquals(listOf(day("2026-09-20"), day("2026-10-02")), gold.history.map { it.date })
        assertEquals(4.5, gold.history[0].quantity)
        assertEquals(null, gold.history[1].quantity)
        assertEquals("first", gold.history[0].note)
        assertEquals(90_000.0, state.loans.single().equity)
        assertEquals(1_500.0, state.lendings.single().remaining)
        val snapshot = state.snapshots.single()
        assertEquals(3_150.0, snapshot.income)
        assertEquals(listOf("Rent", "Netflix"), snapshot.chargeLines.map { it.title })
        assertEquals("housing", snapshot.chargeLines[0].category)
        assertEquals(listOf(2_500.0, 250.0), snapshot.incomeLines.map { it.amount })
        assertEquals(state.budget.left, 2_500.0 + 250.0 - 863.49 - 300.0, 0.001)
    }

    @Test fun itRunsOnce() {
        LegacyImport.run(repo, rows)
        LegacyImport.run(repo, rows)
        assertEquals(2, repo.current.charges.size)
        assertTrue(LegacyImport.isDone(repo))
    }

    @Test fun aNewInstallSkipsIt() {
        LegacyImport.skip(repo)
        LegacyImport.run(repo, rows)
        assertTrue(repo.current.isEmpty)
    }
}

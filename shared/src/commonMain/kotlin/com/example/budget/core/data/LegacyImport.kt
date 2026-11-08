package com.example.budget.core.data

import com.example.budget.core.BudgetCalendar
import com.example.budget.core.BudgetState
import com.example.budget.core.ChargeCategory
import com.example.budget.core.FixedCharge
import com.example.budget.core.IncomeSource
import com.example.budget.core.Investment
import com.example.budget.core.InvestmentKind
import com.example.budget.core.Lending
import com.example.budget.core.LendingSnapshot
import com.example.budget.core.Loan
import com.example.budget.core.LoanSnapshot
import com.example.budget.core.Snapshot
import com.example.budget.core.SnapshotLine
import com.example.budget.core.ValueSnapshot
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import kotlin.time.Instant

/**
 * The rows of the store of the iOS versions before the shared core
 * (SwiftData, saved by Core Data in SQLite). The iOS app reads the file,
 * without changing it, and hands the rows over.
 *
 * Core Data names a table Z + the class name, and a column Z + the property
 * name, both in capitals: `ZFIXEDCHARGE.ZTITLE`. Rows have their id in `Z_PK`,
 * and a to-one relationship is the parent's `Z_PK` (`ZVALUESNAPSHOT.ZINVESTMENT`).
 */
interface LegacyRows {
    /**
     * Every row of `table`, each from column name to its value as text
     * (numbers as Swift prints them, data as UTF-8). NULL values are left out.
     * Empty when the table doesn't exist.
     */
    fun rows(table: String): List<Map<String, String>>
}

/** Moves the data of the earlier iOS versions into the shared database, once. */
object LegacyImport {
    const val DONE_KEY = "legacy-import"

    /** Core Data dates are seconds since 1 January 2001. */
    private const val REFERENCE_DATE_SECONDS = 978_307_200.0

    /** Whether the import was already done (or wasn't needed) for this database. */
    fun isDone(repository: BudgetRepository): Boolean = repository.meta(DONE_KEY) != null

    /**
     * Reads every row and adds it to `repository`, in one transaction, then
     * marks the import as done. Skipped when it was done before or when the
     * database already holds data. Returns what was imported.
     */
    fun run(repository: BudgetRepository, rows: LegacyRows): BudgetState {
        if (isDone(repository)) return BudgetState()
        return repository.batch {
            val state = if (repository.current.isEmpty) read(rows) else BudgetState()
            repository.insertAllNow(state)
            repository.setMeta(DONE_KEY, BudgetCalendar.now().toString())
            state
        }
    }

    /** Marks the import as done without anything to import (a new install). */
    fun skip(repository: BudgetRepository) {
        if (!isDone(repository)) repository.setMeta(DONE_KEY, "none")
    }

    /** Turns the legacy rows into a state, keeping how they relate. */
    fun read(rows: LegacyRows): BudgetState {
        fun table(name: String) = rows.rows(name).map(::Row)

        val lendingHistory = table("ZLENDINGSNAPSHOT").groupBy({ it.long("ZLENDING") }) {
            LendingSnapshot(date = it.date("ZDATE"), remaining = it.double("ZREMAINING"), note = it.text("ZNOTE"))
        }
        val valueHistory = table("ZVALUESNAPSHOT").groupBy({ it.long("ZINVESTMENT") }) {
            ValueSnapshot(
                date = it.date("ZDATE"), value = it.double("ZVALUE"), invested = it.double("ZINVESTED"),
                quantity = it.doubleOrNull("ZQUANTITY"), unitPrice = it.doubleOrNull("ZUNITPRICE"), note = it.text("ZNOTE"),
            )
        }
        val loanHistory = table("ZLOANSNAPSHOT").groupBy({ it.long("ZLOAN") }) {
            LoanSnapshot(
                date = it.date("ZDATE"), remaining = it.double("ZREMAINING"), homeValue = it.double("ZHOMEVALUE"),
                note = it.text("ZNOTE"),
            )
        }

        return BudgetState(
            charges = table("ZFIXEDCHARGE").map {
                FixedCharge(
                    title = it.text("ZTITLE"), amount = it.double("ZAMOUNT"),
                    category = ChargeCategory.fromRaw(it.text("ZCATEGORYRAW", "other")),
                    dayOfMonth = it.long("ZDAYOFMONTH", 1).toInt(), emoji = it.text("ZEMOJI"),
                )
            }.sortedByDescending { it.amount },
            incomeSources = table("ZINCOMESOURCE").map {
                IncomeSource(
                    title = it.text("ZTITLE"), amount = it.double("ZAMOUNT"), emoji = it.text("ZEMOJI", "💼"),
                    isActive = it.long("ZISACTIVE", 1) != 0L, createdAt = it.date("ZCREATEDAT"),
                )
            }.sortedBy { it.createdAt },
            lendings = table("ZLENDING").map {
                Lending(
                    name = it.text("ZNAME"), emoji = it.text("ZEMOJI", "💸"), lent = it.double("ZLENT"),
                    date = it.date("ZDATE"), monthlyRepayment = it.double("ZMONTHLYREPAYMENT"), note = it.text("ZNOTE"),
                    history = lendingHistory[it.long("Z_PK")].orEmpty(),
                )
            }.sortedBy { it.date },
            investments = table("ZINVESTMENT").map {
                Investment(
                    name = it.text("ZNAME"), ticker = it.text("ZTICKER"),
                    kind = InvestmentKind.fromRaw(it.text("ZKINDRAW", "ETF")), emoji = it.text("ZEMOJI"),
                    createdAt = it.date("ZCREATEDAT"), monthlyContribution = it.double("ZMONTHLYCONTRIBUTION"),
                    history = valueHistory[it.long("Z_PK")].orEmpty(),
                )
            }.sortedBy { it.name.lowercase() },
            loans = table("ZLOAN").map {
                Loan(
                    name = it.text("ZNAME"), emoji = it.text("ZEMOJI", "🏠"), borrowed = it.double("ZBORROWED"),
                    createdAt = it.date("ZCREATEDAT"), history = loanHistory[it.long("Z_PK")].orEmpty(),
                )
            }.sortedBy { it.name.lowercase() },
            snapshots = table("ZSNAPSHOT").map {
                Snapshot(
                    date = it.date("ZDATE"), note = it.text("ZNOTE"),
                    mainIncome = it.double("ZMAININCOME"), otherIncome = it.double("ZOTHERINCOME"),
                    repayments = it.double("ZREPAYMENTS"), charges = it.double("ZCHARGES"), savings = it.double("ZSAVINGS"),
                    chargeLines = lines(it.text("ZCHARGELINESDATA")), incomeLines = lines(it.text("ZINCOMELINESDATA")),
                )
            }.sortedBy { it.date },
        )
    }

    /** `[SnapshotLine]` as the iOS app encoded it in JSON. */
    internal fun lines(json: String): List<SnapshotLine> {
        if (json.isBlank()) return emptyList()
        return runCatching {
            Json.parseToJsonElement(json).jsonArray.map { element ->
                val line = element as JsonObject
                SnapshotLine(
                    title = line["title"]?.jsonPrimitive?.contentOrNull ?: "",
                    amount = line["amount"]?.jsonPrimitive?.doubleOrNull ?: 0.0,
                    category = line["category"]?.jsonPrimitive?.contentOrNull ?: "",
                )
            }
        }.getOrDefault(emptyList())
    }

    private class Row(val values: Map<String, String>) {
        fun text(column: String, default: String = ""): String = values[column] ?: default
        fun doubleOrNull(column: String): Double? = values[column]?.toDoubleOrNull()
        fun double(column: String): Double = doubleOrNull(column) ?: 0.0
        fun long(column: String, default: Long = 0): Long =
            values[column]?.let { it.toLongOrNull() ?: it.toDoubleOrNull()?.toLong() } ?: default

        fun date(column: String): Instant = doubleOrNull(column)
            ?.let { BudgetCalendar.fromEpochSeconds(it + REFERENCE_DATE_SECONDS) }
            ?: BudgetCalendar.now()
    }
}

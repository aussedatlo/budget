package com.example.budget.core.wealth

import com.example.budget.core.BudgetCalendar
import kotlin.time.Instant

/** A home loan, followed through snapshots of what's left to repay and what the home is worth. */
data class Loan(
    val id: Long = 0,
    val name: String,
    val emoji: String = "🏠",
    /** Amount borrowed at the start. */
    val borrowed: Double,
    val createdAt: Instant = BudgetCalendar.now(),
    val history: List<LoanSnapshot> = emptyList(),
) {
    /** Newest first. */
    val sortedHistory: List<LoanSnapshot> get() = history.sortedByDescending { it.date }

    fun snapshotAt(date: Instant): LoanSnapshot? = history.filter { it.date <= date }.maxByOrNull { it.date }

    fun entryOn(date: Instant): LoanSnapshot? =
        history.filter { BudgetCalendar.isSameDay(it.date, date) }.maxByOrNull { it.date }

    fun entryInMonthOf(date: Instant): LoanSnapshot? =
        history.filter { BudgetCalendar.isSameMonth(it.date, date) }.maxByOrNull { it.date }

    val latest: LoanSnapshot? get() = history.maxByOrNull { it.date }
    val remaining: Double get() = latest?.remaining ?: borrowed
    val repaid: Double get() = maxOf(borrowed - remaining, 0.0)
    val repaidRatio: Double get() = if (borrowed > 0) minOf(repaid / borrowed, 1.0) else 0.0
    val homeValue: Double get() = latest?.homeValue ?: 0.0
    /** The part of the home that is really ours. */
    val equity: Double get() = homeValue - remaining
    val equityRatio: Double get() = if (homeValue > 0) (equity / homeValue).coerceIn(0.0, 1.0) else 0.0
}

data class LoanSnapshot(
    val id: Long = 0,
    val date: Instant = BudgetCalendar.now(),
    /** Capital left to repay, as on the bank statement. */
    val remaining: Double = 0.0,
    /** Estimated value of the home. */
    val homeValue: Double = 0.0,
    val note: String = "",
)

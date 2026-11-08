package com.example.budget.core

import kotlin.time.Instant

/**
 * A line of income: a salary, freelance work, a lodger, a bonus...
 * Switched off when it doesn't come in, so it stays listed without counting.
 */
data class IncomeSource(
    val id: Long = 0,
    val title: String,
    val amount: Double,
    val emoji: String = "💼",
    val isActive: Boolean = true,
    val createdAt: Instant = BudgetCalendar.now(),
)

/** Money lent to someone, followed like the home loan: what's left to repay is recorded from time to time. */
data class Lending(
    val id: Long = 0,
    /** Who the money was lent to. */
    val name: String,
    val emoji: String = "💸",
    /** Amount lent at the start. */
    val lent: Double,
    val date: Instant = BudgetCalendar.now(),
    /** What they pay back each month, counted as income until it's all repaid. 0 when there's no fixed amount. */
    val monthlyRepayment: Double = 0.0,
    val note: String = "",
    val history: List<LendingSnapshot> = emptyList(),
) {
    /** Newest first. */
    val sortedHistory: List<LendingSnapshot> get() = history.sortedByDescending { it.date }

    /** What was left to repay on the same day as `date`, if recorded. */
    fun entryOn(date: Instant): LendingSnapshot? =
        history.filter { BudgetCalendar.isSameDay(it.date, date) }.maxByOrNull { it.date }

    /** The latest value recorded in the same month as `date`, if any. */
    fun entryInMonthOf(date: Instant): LendingSnapshot? =
        history.filter { BudgetCalendar.isSameMonth(it.date, date) }.maxByOrNull { it.date }

    /** What was still owed at `date`: nothing before the money was lent. */
    fun remainingAt(date: Instant): Double {
        if (this.date > date) return 0.0
        val snapshot = history.filter { it.date <= date }.maxByOrNull { it.date }
        return maxOf(snapshot?.remaining ?: lent, 0.0)
    }

    val latest: LendingSnapshot? get() = history.maxByOrNull { it.date }
    val remaining: Double get() = maxOf(latest?.remaining ?: lent, 0.0)
    val repaid: Double get() = maxOf(lent - remaining, 0.0)
    val repaidRatio: Double get() = if (lent > 0) minOf(repaid / lent, 1.0) else 0.0
    val isSettled: Boolean get() = lent > 0 && remaining <= 0.005
    /** What comes in this month: the monthly repayment, never more than what's left. */
    val expectedThisMonth: Double get() = minOf(monthlyRepayment, remaining)
}

data class LendingSnapshot(
    val id: Long = 0,
    val date: Instant = BudgetCalendar.now(),
    /** What's still owed on that date. */
    val remaining: Double = 0.0,
    val note: String = "",
)

/** Monthly income: the income lines that are switched on, and the monthly repayments of money lent. */
class IncomeTotals(sources: List<IncomeSource>, lendings: List<Lending>) {
    val sources: Double = sources.filter { it.isActive }.sumOf { it.amount }
    val repayments: Double = lendings.sumOf { it.expectedThisMonth }
    val total: Double get() = sources + repayments
}

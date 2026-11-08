package com.example.budget.core.snapshots

import com.example.budget.core.BudgetCalendar
import com.example.budget.core.BudgetState
import com.example.budget.core.wealth.Wealth
import com.example.budget.core.wealth.WealthPoint
import kotlin.time.Instant

/** A charge or an income as it was when a snapshot was taken. */
data class SnapshotLine(
    val title: String,
    val amount: Double,
    /** [ChargeCategory.raw]; empty for income. */
    val category: String = "",
)

/**
 * The whole picture for a month: one snapshot per month. The monthly budget
 * (income, recurring charges, planned savings) is stored here; investments,
 * the home loan and money lent record their values of that month in their own history.
 */
data class Snapshot(
    val id: Long = 0,
    /** When in the month it stands for: the day it was taken, or the last day of the month when it was caught up later. */
    val date: Instant = BudgetCalendar.now(),
    val note: String = "",
    val mainIncome: Double = 0.0,
    val otherIncome: Double = 0.0,
    /** Monthly repayments of money lent. */
    val repayments: Double = 0.0,
    val charges: Double = 0.0,
    /** Planned monthly savings. */
    val savings: Double = 0.0,
    val chargeLines: List<SnapshotLine> = emptyList(),
    val incomeLines: List<SnapshotLine> = emptyList(),
) {
    /** First day of the month it stands for. */
    val month: Instant get() = BudgetCalendar.startOfMonth(date)
    /** Everything recorded up to the end of its month counts. */
    val endOfMonth: Instant get() = BudgetCalendar.endOfMonth(date)

    val income: Double get() = mainIncome + otherIncome + repayments
    /** What was free to spend each month. */
    val left: Double get() = income - charges - savings
    val savingsRate: Double get() = if (income > 0) savings / income else 0.0

    companion object {
        /** Whether the month of `now` already has its snapshot. */
        fun isTakenThisMonth(snapshots: List<Snapshot>, now: Instant = BudgetCalendar.now()): Boolean =
            snapshots.any { BudgetCalendar.isSameMonth(it.date, now) }

        /** Months without a snapshot between the last one and the current month (12 at most, oldest first). */
        fun missingMonths(snapshots: List<Snapshot>, now: Instant = BudgetCalendar.now()): List<Instant> {
            val last = snapshots.maxByOrNull { it.date } ?: return emptyList()
            val current = BudgetCalendar.startOfMonth(now)
            val months = mutableListOf<Instant>()
            var next = BudgetCalendar.addMonths(last.date, 1)
            while (next < current) {
                months += next
                next = BudgetCalendar.addMonths(next, 1)
            }
            return months.takeLast(12)
        }

        /** The date a snapshot of `month` gets: now for the current month, the month's last second for a past one. */
        fun dateFor(month: Instant, now: Instant = BudgetCalendar.now()): Instant =
            if (BudgetCalendar.isSameMonth(month, now)) now else BudgetCalendar.endOfMonth(month)
    }
}

/** A snapshot with the net worth at the end of its month. */
data class SnapshotSummary(
    val snapshot: Snapshot,
    val wealth: WealthPoint,
    /** Net worth change since the previous snapshot. */
    val change: Double?,
)

object Trends {
    /** Every snapshot, newest first, each with the net worth at the end of its month. */
    fun summaries(state: BudgetState): List<SnapshotSummary> {
        var previous: Double? = null
        return state.snapshots.sortedBy { it.date }.map { snapshot ->
            val wealth = Wealth.pointAt(snapshot.endOfMonth, state.investments, state.loans, state.lendings)
            SnapshotSummary(snapshot, wealth, previous?.let { wealth.netWorth - it }).also { previous = wealth.netWorth }
        }.reversed()
    }
}

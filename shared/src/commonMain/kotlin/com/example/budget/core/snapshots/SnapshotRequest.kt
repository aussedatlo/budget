package com.example.budget.core.snapshots

import com.example.budget.core.BudgetCalendar
import com.example.budget.core.BudgetState
import com.example.budget.core.income.Lending
import com.example.budget.core.wealth.Wealth
import com.example.budget.core.wealth.WealthPoint
import kotlin.time.Instant

/**
 * What the snapshot screen holds when saving: the month, and the amounts as
 * checked and fixed there. Anything left out keeps its current value.
 */
data class SnapshotRequest(
    /** Any moment in the month the snapshot is for. */
    val month: Instant,
    val note: String = "",
    val incomeSources: List<SourceEntry> = emptyList(),
    val charges: List<ChargeEntry> = emptyList(),
    /** Only the investments whose values are filled in. */
    val investments: List<InvestmentEntry> = emptyList(),
    /** Only the loans whose values are filled in. */
    val loans: List<LoanEntry> = emptyList(),
    /** Lendings whose repayment didn't come in this month. */
    val skippedRepayments: Set<Long> = emptySet(),
    /** Investments whose planned saving wasn't made this month. */
    val skippedSavings: Set<Long> = emptySet(),
    val now: Instant = BudgetCalendar.now(),
) {
    /** The request starting from the current values of everything: what the screen shows before any change. */
    companion object {
        fun from(state: BudgetState, month: Instant, now: Instant = BudgetCalendar.now()) = SnapshotRequest(
            month = month,
            incomeSources = state.incomeSources.map { SourceEntry(it.id, it.amount, it.isActive) },
            charges = state.charges.map { ChargeEntry(it.id, it.amount) },
            investments = state.investments.mapNotNull { investment ->
                investment.latest?.let { InvestmentEntry(investment.id, it.value, it.quantity, it.unitPrice) }
            },
            loans = state.loans.map { loan ->
                LoanEntry(loan.id, loan.latest?.remaining ?: loan.borrowed, loan.latest?.homeValue ?: 0.0)
            },
            now = now,
        )
    }

    /** What would be saved, with the totals the screen shows. */
    fun plan(state: BudgetState): SnapshotPlan = SnapshotPlan(this, state)
}

/** An income line as checked in the snapshot. */
data class SourceEntry(val id: Long, val amount: Double, val isActive: Boolean)

/** A recurring charge as checked in the snapshot. */
data class ChargeEntry(val id: Long, val amount: Double)

/** What an investment is worth that month. */
data class InvestmentEntry(val id: Long, val value: Double, val quantity: Double? = null, val unitPrice: Double? = null)

/** Where the home loan stands that month. */
data class LoanEntry(val id: Long, val remaining: Double, val homeValue: Double)

/** The totals and lines of a [SnapshotRequest], as they would be saved. */
class SnapshotPlan internal constructor(request: SnapshotRequest, state: BudgetState) {
    val isCurrentMonth: Boolean = BudgetCalendar.isSameMonth(request.month, request.now)
    /** The current month is dated now; a month caught up later, on its last day. */
    val date: Instant = Snapshot.dateFor(request.month, request.now)

    /** The snapshot already taken that month, replaced on save. */
    val replaces: Snapshot? = state.snapshots.firstOrNull { BudgetCalendar.isSameMonth(it.date, date) }

    /** The latest snapshot of an earlier month. */
    val previous: Snapshot? = state.snapshots.lastOrNull { it.date < BudgetCalendar.startOfMonth(date) }

    /** Money lent that isn't fully repaid yet. */
    val openLendings: List<Lending> = state.lendings.filter { !it.isSettled }

    val incomeLines: List<SnapshotLine>
    val sourcesIncome: Double
    val repayments: Double
    val chargeLines: List<SnapshotLine>
    val charges: Double
    val savings: Double

    init {
        val entries = request.incomeSources.associateBy { it.id }
        val lines = mutableListOf<SnapshotLine>()
        var sources = 0.0
        for (source in state.incomeSources) {
            val entry = entries[source.id]
            val amount = maxOf(entry?.amount ?: source.amount, 0.0)
            if (entry?.isActive ?: source.isActive) {
                sources += amount
                lines += SnapshotLine(source.title, amount)
            }
        }
        var repaid = 0.0
        for (lending in openLendings) {
            if (lending.id in request.skippedRepayments) continue
            val amount = repayment(lending)
            if (amount <= 0) continue
            repaid += amount
            lines += SnapshotLine("Repaid by ${lending.name}", amount)
        }
        incomeLines = lines
        sourcesIncome = sources
        repayments = repaid

        val chargeEntries = request.charges.associateBy { it.id }
        chargeLines = state.charges.map { charge ->
            SnapshotLine(charge.title, maxOf(chargeEntries[charge.id]?.amount ?: charge.amount, 0.0), charge.category.raw)
        }
        charges = chargeLines.sumOf { it.amount }
        savings = state.investments.filter { it.id !in request.skippedSavings }.sumOf { it.monthlyContribution }
    }

    val income: Double get() = sourcesIncome + repayments
    /** What's left each month. */
    val left: Double get() = income - charges - savings

    /** Net worth with the values typed in. */
    val netWorth: Double = run {
        val investments = request.investments.associateBy { it.id }
        val loans = request.loans.associateBy { it.id }
        state.investments.sumOf { investment ->
            investments[investment.id]?.value ?: investment.latest?.value ?: 0.0
        } + state.loans.sumOf { loan ->
            val entry = loans[loan.id]
            if (entry != null) entry.homeValue - entry.remaining else loan.homeValue - loan.remaining
        } + openLendings.sumOf { it.remaining }
    }

    /** Net worth at the end of the previous snapshot's month. */
    val previousWealth: WealthPoint? =
        previous?.let { Wealth.pointAt(it.endOfMonth, state.investments, state.loans, state.lendings) }

    companion object {
        /** What `lending` repays this month: never more than what is left. */
        fun repayment(lending: Lending): Double = minOf(lending.monthlyRepayment, lending.remaining)
    }
}

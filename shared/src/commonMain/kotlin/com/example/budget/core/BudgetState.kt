package com.example.budget.core

import com.example.budget.core.charges.FixedCharge
import com.example.budget.core.income.IncomeSource
import com.example.budget.core.income.IncomeTotals
import com.example.budget.core.income.Lending
import com.example.budget.core.snapshots.Snapshot
import com.example.budget.core.wealth.Investment
import com.example.budget.core.wealth.Loan
import com.example.budget.core.wealth.Wealth
import com.example.budget.core.wealth.WealthPoint

/** Everything the app holds, sorted the way the screens list it. */
data class BudgetState(
    /** Largest first. */
    val charges: List<FixedCharge> = emptyList(),
    /** Oldest first. */
    val incomeSources: List<IncomeSource> = emptyList(),
    /** Oldest first. */
    val lendings: List<Lending> = emptyList(),
    /** By name. */
    val investments: List<Investment> = emptyList(),
    /** By name. */
    val loans: List<Loan> = emptyList(),
    /** Oldest first. */
    val snapshots: List<Snapshot> = emptyList(),
) {
    val incomeTotals: IncomeTotals get() = IncomeTotals(incomeSources, lendings)
    val budget: BudgetSummary get() = BudgetSummary(this)
    val wealth: WealthPoint get() = Wealth.current(investments, loans, lendings)

    /** Investments with a savings plan. */
    val savers: List<Investment> get() = investments.filter { it.monthlyContribution > 0 }

    fun charge(id: Long): FixedCharge? = charges.firstOrNull { it.id == id }
    fun incomeSource(id: Long): IncomeSource? = incomeSources.firstOrNull { it.id == id }
    fun lending(id: Long): Lending? = lendings.firstOrNull { it.id == id }
    fun investment(id: Long): Investment? = investments.firstOrNull { it.id == id }
    fun loan(id: Long): Loan? = loans.firstOrNull { it.id == id }
    fun snapshot(id: Long): Snapshot? = snapshots.firstOrNull { it.id == id }

    val isEmpty: Boolean
        get() = charges.isEmpty() && incomeSources.isEmpty() && lendings.isEmpty() &&
            investments.isEmpty() && loans.isEmpty() && snapshots.isEmpty()
}

/** The Budget tab: monthly income minus recurring charges and planned savings. */
class BudgetSummary(state: BudgetState) {
    /** Income lines switched on and monthly repayments (Income tab). */
    val income: Double = state.incomeTotals.total
    val charges: Double = state.charges.sumOf { it.amount }
    val savings: Double = state.savers.sumOf { it.monthlyContribution }
    /** What's really free to spend: income minus charges and planned savings. */
    val left: Double get() = income - charges - savings
    val isOverBudget: Boolean get() = left < 0

    val title: String
        get() = when {
            left < 0 -> "Over budget"
            savings > 0 -> "Left after savings"
            else -> "Left this month"
        }
}

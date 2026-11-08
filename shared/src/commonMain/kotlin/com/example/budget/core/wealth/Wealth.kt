package com.example.budget.core.wealth

import com.example.budget.core.BudgetCalendar
import com.example.budget.core.income.Lending
import kotlin.time.Instant

/** Investments, home equity and money lent on a given day. */
data class WealthPoint(
    val date: Instant,
    val investments: Double,
    val invested: Double,
    val homeEquity: Double,
    val lent: Double,
) {
    val netWorth: Double get() = investments + homeEquity + lent
}

object Wealth {
    /** Everything counted with its latest values on or before `date`. */
    fun pointAt(date: Instant, investments: List<Investment>, loans: List<Loan>, lendings: List<Lending>): WealthPoint {
        val values = investments.mapNotNull { it.snapshotAt(date) }
        val homes = loans.mapNotNull { it.snapshotAt(date) }
        return WealthPoint(
            date = date,
            investments = values.sumOf { it.value },
            invested = values.sumOf { it.invested },
            homeEquity = homes.sumOf { it.homeValue - it.remaining },
            lent = lendings.sumOf { it.remainingAt(date) },
        )
    }

    /** Everything counted with its latest values. */
    fun current(investments: List<Investment>, loans: List<Loan>, lendings: List<Lending>): WealthPoint =
        pointAt(BudgetCalendar.distantFuture, investments, loans, lendings)

    /** One point per day on which something was recorded. */
    fun points(investments: List<Investment>, loans: List<Loan>, lendings: List<Lending>): List<WealthPoint> {
        val dates = investments.flatMap { i -> i.history.map { it.date } } +
            loans.flatMap { l -> l.history.map { it.date } } +
            lendings.flatMap { l -> listOf(l.date) + l.history.map { it.date } }
        val days = dates.map { BudgetCalendar.startOfDay(it) }.distinct().sorted()
        return days.map { day ->
            pointAt(BudgetCalendar.endOfDay(day), investments, loans, lendings).copy(date = day)
        }
    }
}

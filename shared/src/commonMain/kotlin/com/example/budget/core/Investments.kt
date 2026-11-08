package com.example.budget.core

import kotlin.math.abs
import kotlin.time.Instant

enum class InvestmentKind(val raw: String, val emoji: String, val tint: Tint) {
    STOCK("Stock", "📈", Tint.SKY),
    ETF("ETF", "🌍", Tint.MINT),
    FUND("Fund", "💼", Tint.LAVENDER),
    CRYPTO("Crypto", "🪙", Tint.PEACH),
    METAL("Precious metal", "🥇", Tint.BUTTER),
    SAVINGS("Savings", "🐷", Tint.PINK),
    REAL_ESTATE("Real estate", "🏠", Tint.PEACH),
    OTHER("Other", "💎", Tint.LAVENDER);

    val label: String get() = raw

    companion object {
        val all: List<InvestmentKind> = entries.toList()
        fun fromRaw(raw: String): InvestmentKind = entries.firstOrNull { it.raw == raw } ?: OTHER
    }
}

/**
 * A position (ETF, gold coins, crypto, savings account...). Its history records,
 * from time to time, what it's worth and how much money was put in so far.
 */
data class Investment(
    val id: Long = 0,
    val name: String,
    val ticker: String = "",
    val kind: InvestmentKind = InvestmentKind.ETF,
    /** Empty: the kind's emoji. */
    val emoji: String = "",
    val createdAt: Instant = BudgetCalendar.now(),
    /** Savings plan: money added every month (0 = none). */
    val monthlyContribution: Double = 0.0,
    val history: List<ValueSnapshot> = emptyList(),
) {
    val displayEmoji: String get() = emoji.ifEmpty { kind.emoji }

    /** Newest first. */
    val sortedHistory: List<ValueSnapshot> get() = history.sortedByDescending { it.date }

    /** The most recent snapshot on or before a date. */
    fun snapshotAt(date: Instant): ValueSnapshot? = history.filter { it.date <= date }.maxByOrNull { it.date }

    /** The values recorded on the same day as `date`, if any. */
    fun entryOn(date: Instant): ValueSnapshot? =
        history.filter { BudgetCalendar.isSameDay(it.date, date) }.maxByOrNull { it.date }

    /** The latest values recorded in the same month as `date`, if any. */
    fun entryInMonthOf(date: Instant): ValueSnapshot? =
        history.filter { BudgetCalendar.isSameMonth(it.date, date) }.maxByOrNull { it.date }

    val latest: ValueSnapshot? get() = history.maxByOrNull { it.date }
    val currentValue: Double get() = latest?.value ?: 0.0
    val investedAmount: Double get() = latest?.invested ?: 0.0
    val gain: Double get() = currentValue - investedAmount
    val gainRatio: Double get() = if (investedAmount > 0) gain / investedAmount else 0.0

    /**
     * "Invested so far" for the snapshot of `date`'s month: the amount recorded
     * before that month plus the savings plan for each month since, this month's
     * saving left out when it's switched off. Retaking a month starts again from
     * the month before, so the saving isn't added twice, but an amount corrected
     * by hand on the Wealth tab that month is kept.
     */
    fun investedForSnapshot(date: Instant, savingIncluded: Boolean): Double {
        val month = BudgetCalendar.startOfMonth(date)
        val existing = entryInMonthOf(date)
        val previous = history.filter { it.date < month }.maxByOrNull { it.date }
            ?: return existing?.invested ?: latest?.invested ?: 0.0
        val months = BudgetCalendar.monthsBetween(previous.date, date)
        val withSaving = previous.invested + monthlyContribution * months
        val withoutSaving = withSaving - monthlyContribution
        if (existing != null && abs(existing.invested - withSaving) > 0.005 &&
            abs(existing.invested - withoutSaving) > 0.005
        ) {
            return existing.invested
        }
        return if (savingIncluded) withSaving else withoutSaving
    }
}

/**
 * What a position is worth at a date, and how much was put in so far.
 * Quantity and unit price are optional; when both are set, value = quantity × unit price.
 */
data class ValueSnapshot(
    val id: Long = 0,
    val date: Instant = BudgetCalendar.now(),
    val value: Double = 0.0,
    val invested: Double = 0.0,
    val quantity: Double? = null,
    val unitPrice: Double? = null,
    val note: String = "",
) {
    val gain: Double get() = value - invested
    val tracksUnits: Boolean get() = quantity != null && unitPrice != null
}

data class HistoryPoint(val date: Instant, val value: Double, val invested: Double)

object History {
    /** One point per day with a snapshot; each position counts with its latest snapshot on that day. */
    fun points(investments: List<Investment>): List<HistoryPoint> {
        val days = investments.flatMap { i -> i.history.map { BudgetCalendar.startOfDay(it.date) } }.distinct().sorted()
        return days.map { day ->
            val endOfDay = BudgetCalendar.endOfDay(day)
            val snapshots = investments.mapNotNull { it.snapshotAt(endOfDay) }
            HistoryPoint(day, snapshots.sumOf { it.value }, snapshots.sumOf { it.invested })
        }
    }
}

data class SavingsPoint(val month: Instant, val investment: String, val amount: Double)

object Savings {
    /**
     * Money saved each month, per position: the change in "invested so far"
     * between two snapshots, counted in the month of the later one. Market
     * moves don't count, only money put in or taken out.
     */
    fun monthly(investments: List<Investment>, months: Int = 12, now: Instant = BudgetCalendar.now()): List<SavingsPoint> {
        val firstMonth = BudgetCalendar.addMonths(now, -(months - 1))
        val totals = mutableMapOf<Instant, MutableMap<String, Double>>()
        for (investment in investments) {
            val history = investment.history.sortedBy { it.date }
            for ((previous, snapshot) in history.zipWithNext()) {
                val month = BudgetCalendar.startOfMonth(snapshot.date)
                if (month < firstMonth) continue
                val added = snapshot.invested - previous.invested
                if (added == 0.0) continue
                val perInvestment = totals.getOrPut(month) { mutableMapOf() }
                perInvestment[investment.name] = (perInvestment[investment.name] ?: 0.0) + added
            }
        }
        return totals.keys.sorted().flatMap { month ->
            totals.getValue(month).entries.sortedBy { it.key }.map { SavingsPoint(month, it.key, it.value) }
        }
    }
}

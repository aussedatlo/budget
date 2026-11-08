package com.example.budget.core

import com.example.budget.core.charges.ChargeCategory
import com.example.budget.core.charges.FixedCharge
import com.example.budget.core.income.IncomeSource
import com.example.budget.core.income.Lending
import com.example.budget.core.income.LendingSnapshot
import com.example.budget.core.snapshots.Snapshot
import com.example.budget.core.snapshots.SnapshotLine
import com.example.budget.core.wealth.Investment
import com.example.budget.core.wealth.InvestmentKind
import com.example.budget.core.wealth.Loan
import com.example.budget.core.wealth.LoanSnapshot
import com.example.budget.core.wealth.ValueSnapshot
import kotlin.time.Instant

/**
 * Sample data for the UI tests and screenshots of both apps. It's loaded
 * into a database in memory: it never touches the user's real data.
 */
object DemoData {
    private data class ChargeSeed(
        val title: String, val amount: Double, val category: ChargeCategory, val day: Int, val emoji: String,
    )

    private val charges = listOf(
        ChargeSeed("Rent", 850.0, ChargeCategory.HOUSING, 5, ""),
        ChargeSeed("Electricity", 64.0, ChargeCategory.UTILITIES, 8, "⚡️"),
        ChargeSeed("Internet", 29.99, ChargeCategory.UTILITIES, 10, "📶"),
        ChargeSeed("Car insurance", 48.50, ChargeCategory.INSURANCE, 12, ""),
        ChargeSeed("Netflix", 13.49, ChargeCategory.SUBSCRIPTIONS, 15, ""),
        ChargeSeed("Yoga", 35.0, ChargeCategory.HEALTH, 1, "🧘‍♀️"),
    )

    /**
     * Everything at once. `missedMonths` leaves out the snapshots of that many
     * months before the current one, and the current month's, to test catching up.
     */
    fun state(missedMonths: Int = 0, now: Instant = BudgetCalendar.now()): BudgetState {
        val monthStart = BudgetCalendar.startOfMonth(now)
        fun monthsAgo(months: Int, day: Int = 1): Instant =
            BudgetCalendar.addDays(BudgetCalendar.addMonths(monthStart, -months), day - 1)

        // Income: a salary, freelance work this month, no tutoring
        val incomeSources = listOf(
            IncomeSource(title = "Salary", amount = 2_500.0, emoji = "🏢", createdAt = BudgetCalendar.distantPast),
            IncomeSource(title = "Freelance", amount = 400.0, emoji = "💼", createdAt = now),
            IncomeSource(title = "Tutoring", amount = 150.0, emoji = "🎓", isActive = false, createdAt = now),
        )

        // Money lent: Lucas pays back 250 € a month, Emma when she can
        val lendings = listOf(
            Lending(
                name = "Lucas", emoji = "🚗", lent = 3_000.0, date = monthsAgo(7, day = 3), monthlyRepayment = 250.0,
                history = listOf(5 to 2_500.0, 3 to 2_000.0, 1 to 1_500.0).map { (months, remaining) ->
                    LendingSnapshot(date = monthsAgo(months, day = 5), remaining = remaining)
                },
            ),
            Lending(
                name = "Emma", emoji = "🎓", lent = 600.0, date = monthsAgo(2, day = 12),
                history = listOf(
                    LendingSnapshot(date = monthsAgo(1, day = 20), remaining = 400.0, note = "Paid back 200 in cash"),
                ),
            ),
        )

        // Investments: a snapshot of everything every month over a year
        val etf = mutableListOf<ValueSnapshot>()
        val crypto = mutableListOf<ValueSnapshot>()
        val savings = mutableListOf<ValueSnapshot>()
        val gold = mutableListOf<ValueSnapshot>()
        val snapshots = mutableListOf<Snapshot>()
        var goldCoins = 4.0
        for (i in 0 until 12) {
            val date = minOf(monthsAgo(11 - i, day = 20), now)
            val step = i.toDouble()

            val shares = 10 + step
            val etfPrice = 420 + step * 6 + (if (i % 3 == 0) -9 else 4)
            etf += ValueSnapshot(date = date, value = shares * etfPrice, invested = shares * 418,
                quantity = shares, unitPrice = etfPrice)

            val btcPrice = 52_000 + step * 2_600 + (if (i % 2 == 0) 4_000 else -3_500)
            val coins = if (i < 6) 0.05 else 0.08
            crypto += ValueSnapshot(date = date, value = coins * btcPrice, invested = if (i < 6) 2_510.0 else 4_348.0,
                quantity = coins, unitPrice = btcPrice)

            val saved = 5_000 + 200 * step
            savings += ValueSnapshot(date = date, value = saved * (1 + 0.0025 * step), invested = saved)

            if (i >= 1) {
                // Gold dips some months: savings still count, only the value moves
                val goldPrice = 395 + step * 11 + (if (i % 4 == 0) -30 else 0)
                if (i >= 2) goldCoins += 300 / goldPrice
                gold += ValueSnapshot(date = date, value = goldCoins * goldPrice, invested = 1_592 + 300.0 * (i - 1),
                    quantity = goldCoins, unitPrice = goldPrice)
            }

            if (missedMonths > 0 && i >= 11 - missedMonths) continue
            // The monthly budget that month: a raise, a rent increase, new subscriptions
            val salary = if (i < 5) 2_350.0 else 2_500.0
            val freelance = if (i % 3 == 0) 400.0 else 0.0
            val repayments = if (i >= 5) 250.0 else 0.0
            val chargeLines = charges
                .filter { (it.title != "Netflix" || i >= 3) && (it.title != "Yoga" || i >= 7) }
                .map { SnapshotLine(it.title, if (it.title == "Rent" && i < 6) 820.0 else it.amount, it.category.raw) }
            val incomeLines = buildList {
                add(SnapshotLine("Salary", salary))
                if (freelance > 0) add(SnapshotLine("Freelance", freelance))
                if (repayments > 0) add(SnapshotLine("Repaid by Lucas", repayments))
            }
            snapshots += Snapshot(
                date = date,
                otherIncome = salary + freelance,
                repayments = repayments,
                savings = if (i >= 1) 500.0 else 200.0,
                charges = chargeLines.sumOf { it.amount },
                chargeLines = chargeLines,
                incomeLines = incomeLines,
            )
        }

        // Home loan: values recorded every 6 months over 4 years
        val home = Loan(
            name = "Apartment", borrowed = 240_000.0, createdAt = now,
            history = (0..8).map { half ->
                LoanSnapshot(
                    date = minOf(monthsAgo(48 - half * 6, day = 10), now),
                    remaining = 240_000 - half * 12_400.0 - (half * half) * 90.0,
                    homeValue = 265_000 + half * 2_500.0,
                )
            },
        )

        return BudgetState(
            charges = charges.map { FixedCharge(title = it.title, amount = it.amount, category = it.category, dayOfMonth = it.day, emoji = it.emoji) },
            incomeSources = incomeSources,
            lendings = lendings,
            investments = listOf(
                Investment(name = "MSCI World", ticker = "CW8", kind = InvestmentKind.ETF, createdAt = now, history = etf),
                Investment(name = "Bitcoin", ticker = "BTC", kind = InvestmentKind.CRYPTO, createdAt = now, history = crypto),
                // Savings plan: 200 € to the savings account and 300 € to gold every month
                Investment(name = "Savings account", kind = InvestmentKind.SAVINGS, createdAt = now,
                    monthlyContribution = 200.0, history = savings),
                Investment(name = "Gold coins", ticker = "XAU", kind = InvestmentKind.METAL, createdAt = now,
                    monthlyContribution = 300.0, history = gold),
            ),
            loans = listOf(home),
            snapshots = snapshots,
        )
    }
}

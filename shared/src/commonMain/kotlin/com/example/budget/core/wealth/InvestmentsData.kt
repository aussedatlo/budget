package com.example.budget.core.wealth

import com.example.budget.core.data.instant
import com.example.budget.core.data.lastId
import com.example.budget.core.data.millis
import com.example.budget.core.db.BudgetDatabase

/** Investments and their values in the database. Called by `BudgetRepository`, inside its transactions. */
internal class InvestmentsData(private val db: BudgetDatabase) {
    private val queries get() = db.investmentsQueries

    /** By name, each with its history. */
    fun load(): List<Investment> {
        val history = queries.selectAllSnapshots().executeAsList().groupBy({ it.investment_id }) {
            ValueSnapshot(it.id, it.date.instant, it.value_, it.invested, it.quantity, it.unit_price, it.note)
        }
        return queries.selectAll().executeAsList().map {
            Investment(it.id, it.name, it.ticker, InvestmentKind.fromRaw(it.kind), it.emoji, it.created_at.instant,
                it.monthly_contribution, history[it.id].orEmpty())
        }
    }

    /** Adds the investment with its history when its id is 0, else updates the investment only. Returns its id. */
    fun save(investment: Investment): Long = if (investment.id == 0L) {
        queries.insert(
            investment.name, investment.ticker, investment.kind.raw, investment.emoji,
            investment.createdAt.millis, investment.monthlyContribution,
        )
        val id = db.lastId()
        investment.history.forEach { saveSnapshot(id, it.copy(id = 0)) }
        id
    } else {
        queries.update(
            investment.name, investment.ticker, investment.kind.raw, investment.emoji,
            investment.createdAt.millis, investment.monthlyContribution, investment.id,
        )
        investment.id
    }

    fun delete(id: Long) {
        queries.deleteSnapshotsOf(id)
        queries.delete(id)
    }

    /** What goes to the investment every month, never below 0. */
    fun updateContribution(id: Long, amount: Double) = queries.updateContribution(maxOf(amount, 0.0), id)

    fun saveSnapshot(investmentId: Long, snapshot: ValueSnapshot): Long = if (snapshot.id == 0L) {
        queries.insertSnapshot(
            investmentId, snapshot.date.millis, snapshot.value, snapshot.invested, snapshot.quantity,
            snapshot.unitPrice, snapshot.note,
        )
        db.lastId()
    } else {
        queries.updateSnapshot(
            snapshot.date.millis, snapshot.value, snapshot.invested, snapshot.quantity, snapshot.unitPrice,
            snapshot.note, snapshot.id,
        )
        snapshot.id
    }

    fun deleteSnapshot(id: Long) = queries.deleteSnapshot(id)

    /** Removes the values recorded between two moments, in epoch milliseconds. */
    fun deleteSnapshotsInRange(from: Long, to: Long) = queries.deleteSnapshotsInRange(from, to)

    fun deleteAll() = queries.deleteAll()
}

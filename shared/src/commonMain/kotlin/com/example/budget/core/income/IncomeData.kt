package com.example.budget.core.income

import com.example.budget.core.data.instant
import com.example.budget.core.data.lastId
import com.example.budget.core.data.millis
import com.example.budget.core.data.toLong
import com.example.budget.core.db.BudgetDatabase

/** Income lines in the database. Called by `BudgetRepository`, inside its transactions. */
internal class IncomeData(private val db: BudgetDatabase) {
    private val queries get() = db.incomeQueries

    /** Oldest first. */
    fun load(): List<IncomeSource> = queries.selectAll().executeAsList().map {
        IncomeSource(it.id, it.title, it.amount, it.emoji, it.is_active != 0L, it.created_at.instant)
    }

    /** Adds the income line when its id is 0, else updates it. Returns its id. */
    fun save(source: IncomeSource): Long = if (source.id == 0L) {
        queries.insert(source.title, source.amount, source.emoji, source.isActive.toLong(), source.createdAt.millis)
        db.lastId()
    } else {
        queries.update(source.title, source.amount, source.emoji, source.isActive.toLong(), source.createdAt.millis, source.id)
        source.id
    }

    fun updateAmount(id: Long, amount: Double, isActive: Boolean) =
        queries.updateAmount(maxOf(amount, 0.0), isActive.toLong(), id)

    fun delete(id: Long) = queries.delete(id)

    fun deleteAll() = queries.deleteAll()
}

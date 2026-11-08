package com.example.budget.core.charges

import com.example.budget.core.data.lastId
import com.example.budget.core.db.BudgetDatabase

/** Recurring charges in the database. Called by `BudgetRepository`, inside its transactions. */
internal class ChargesData(private val db: BudgetDatabase) {
    private val queries get() = db.chargesQueries

    /** Largest first. */
    fun load(): List<FixedCharge> = queries.selectAll().executeAsList().map {
        FixedCharge(it.id, it.title, it.amount, ChargeCategory.fromRaw(it.category), it.day_of_month.toInt(), it.emoji)
    }

    /** Adds the charge when its id is 0, else updates it. Returns its id. */
    fun save(charge: FixedCharge): Long = if (charge.id == 0L) {
        queries.insert(charge.title, charge.amount, charge.category.raw, charge.dayOfMonth.toLong(), charge.emoji)
        db.lastId()
    } else {
        queries.update(charge.title, charge.amount, charge.category.raw, charge.dayOfMonth.toLong(), charge.emoji, charge.id)
        charge.id
    }

    fun updateAmount(id: Long, amount: Double) = queries.updateAmount(maxOf(amount, 0.0), id)

    fun delete(id: Long) = queries.delete(id)

    fun deleteAll() = queries.deleteAll()
}

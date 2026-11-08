package com.example.budget.core.income

import com.example.budget.core.data.instant
import com.example.budget.core.data.lastId
import com.example.budget.core.data.millis
import com.example.budget.core.db.BudgetDatabase

/** Money lent and its history in the database. Called by `BudgetRepository`, inside its transactions. */
internal class LendingsData(private val db: BudgetDatabase) {
    private val queries get() = db.lendingsQueries

    /** Oldest first, each with its history. */
    fun load(): List<Lending> {
        val history = queries.selectAllSnapshots().executeAsList().groupBy({ it.lending_id }) {
            LendingSnapshot(it.id, it.date.instant, it.remaining, it.note)
        }
        return queries.selectAll().executeAsList().map {
            Lending(it.id, it.name, it.emoji, it.lent, it.date.instant, it.monthly_repayment, it.note, history[it.id].orEmpty())
        }
    }

    /** Adds the lending with its history when its id is 0, else updates the lending only. Returns its id. */
    fun save(lending: Lending): Long = if (lending.id == 0L) {
        queries.insert(lending.name, lending.emoji, lending.lent, lending.date.millis, lending.monthlyRepayment, lending.note)
        val id = db.lastId()
        lending.history.forEach { saveSnapshot(id, it.copy(id = 0)) }
        id
    } else {
        queries.update(lending.name, lending.emoji, lending.lent, lending.date.millis, lending.monthlyRepayment, lending.note, lending.id)
        lending.id
    }

    fun delete(id: Long) {
        queries.deleteSnapshotsOf(id)
        queries.delete(id)
    }

    fun saveSnapshot(lendingId: Long, snapshot: LendingSnapshot): Long = if (snapshot.id == 0L) {
        queries.insertSnapshot(lendingId, snapshot.date.millis, snapshot.remaining, snapshot.note)
        db.lastId()
    } else {
        queries.updateSnapshot(snapshot.date.millis, snapshot.remaining, snapshot.note, snapshot.id)
        snapshot.id
    }

    fun deleteSnapshot(id: Long) = queries.deleteSnapshot(id)

    /** Removes the values recorded between two moments, in epoch milliseconds. */
    fun deleteSnapshotsInRange(from: Long, to: Long) = queries.deleteSnapshotsInRange(from, to)

    fun deleteAll() = queries.deleteAll()
}

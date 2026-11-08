package com.example.budget.core.snapshots

import com.example.budget.core.data.instant
import com.example.budget.core.data.lastId
import com.example.budget.core.data.millis
import com.example.budget.core.db.BudgetDatabase

/** Monthly snapshots and their lines in the database. Called by `BudgetRepository`, inside its transactions. */
internal class SnapshotsData(private val db: BudgetDatabase) {
    private val queries get() = db.snapshotsQueries

    /** Oldest first, each with its lines. */
    fun load(): List<Snapshot> {
        val lines = queries.selectAllLines().executeAsList().groupBy { it.snapshot_id }
        return queries.selectAll().executeAsList().map { row ->
            val own = lines[row.id].orEmpty()
            Snapshot(
                row.id, row.date.instant, row.note, row.main_income, row.other_income, row.repayments,
                row.charges, row.savings,
                chargeLines = own.filter { it.kind == CHARGE }.map { SnapshotLine(it.title, it.amount, it.category) },
                incomeLines = own.filter { it.kind == INCOME }.map { SnapshotLine(it.title, it.amount, it.category) },
            )
        }
    }

    /** Adds the snapshot when its id is 0, else replaces it, lines included. Returns its id. */
    fun save(snapshot: Snapshot): Long {
        val id = if (snapshot.id == 0L) {
            queries.insert(snapshot.date.millis, snapshot.note, snapshot.mainIncome, snapshot.otherIncome,
                snapshot.repayments, snapshot.charges, snapshot.savings)
            db.lastId()
        } else {
            queries.update(snapshot.date.millis, snapshot.note, snapshot.mainIncome, snapshot.otherIncome,
                snapshot.repayments, snapshot.charges, snapshot.savings, snapshot.id)
            queries.deleteLinesOf(snapshot.id)
            snapshot.id
        }
        snapshot.chargeLines.forEachIndexed { i, line -> queries.insertLine(id, CHARGE, i.toLong(), line.title, line.amount, line.category) }
        snapshot.incomeLines.forEachIndexed { i, line -> queries.insertLine(id, INCOME, i.toLong(), line.title, line.amount, line.category) }
        return id
    }

    fun delete(id: Long) {
        queries.deleteLinesOf(id)
        queries.delete(id)
    }

    fun deleteAll() = queries.deleteAll()

    private companion object {
        const val CHARGE = "charge"
        const val INCOME = "income"
    }
}

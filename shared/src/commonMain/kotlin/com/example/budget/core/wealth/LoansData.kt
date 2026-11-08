package com.example.budget.core.wealth

import com.example.budget.core.data.instant
import com.example.budget.core.data.lastId
import com.example.budget.core.data.millis
import com.example.budget.core.db.BudgetDatabase

/** Home loans and their values in the database. Called by `BudgetRepository`, inside its transactions. */
internal class LoansData(private val db: BudgetDatabase) {
    private val queries get() = db.loansQueries

    /** By name, each with its history. */
    fun load(): List<Loan> {
        val history = queries.selectAllSnapshots().executeAsList().groupBy({ it.loan_id }) {
            LoanSnapshot(it.id, it.date.instant, it.remaining, it.home_value, it.note)
        }
        return queries.selectAll().executeAsList().map {
            Loan(it.id, it.name, it.emoji, it.borrowed, it.created_at.instant, history[it.id].orEmpty())
        }
    }

    /** Adds the loan with its history when its id is 0, else updates the loan only. Returns its id. */
    fun save(loan: Loan): Long = if (loan.id == 0L) {
        queries.insert(loan.name, loan.emoji, loan.borrowed, loan.createdAt.millis)
        val id = db.lastId()
        loan.history.forEach { saveSnapshot(id, it.copy(id = 0)) }
        id
    } else {
        queries.update(loan.name, loan.emoji, loan.borrowed, loan.createdAt.millis, loan.id)
        loan.id
    }

    fun delete(id: Long) {
        queries.deleteSnapshotsOf(id)
        queries.delete(id)
    }

    fun saveSnapshot(loanId: Long, snapshot: LoanSnapshot): Long = if (snapshot.id == 0L) {
        queries.insertSnapshot(loanId, snapshot.date.millis, snapshot.remaining, snapshot.homeValue, snapshot.note)
        db.lastId()
    } else {
        queries.updateSnapshot(snapshot.date.millis, snapshot.remaining, snapshot.homeValue, snapshot.note, snapshot.id)
        snapshot.id
    }

    fun deleteSnapshot(id: Long) = queries.deleteSnapshot(id)

    /** Removes the values recorded between two moments, in epoch milliseconds. */
    fun deleteSnapshotsInRange(from: Long, to: Long) = queries.deleteSnapshotsInRange(from, to)

    fun deleteAll() = queries.deleteAll()
}

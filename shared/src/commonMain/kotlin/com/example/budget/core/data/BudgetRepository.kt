package com.example.budget.core.data

import app.cash.sqldelight.db.SqlDriver
import com.example.budget.core.BudgetCalendar
import com.example.budget.core.BudgetState
import com.example.budget.core.ChargeCategory
import com.example.budget.core.FixedCharge
import com.example.budget.core.IncomeSource
import com.example.budget.core.Investment
import com.example.budget.core.InvestmentKind
import com.example.budget.core.Lending
import com.example.budget.core.LendingSnapshot
import com.example.budget.core.Loan
import com.example.budget.core.LoanSnapshot
import com.example.budget.core.Snapshot
import com.example.budget.core.SnapshotLine
import com.example.budget.core.ValueSnapshot
import com.example.budget.core.db.BudgetDatabase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.time.Instant

/**
 * The one way in and out of the database, for both apps.
 *
 * Every call is synchronous (the data is small) and runs in a transaction.
 * After each change, [state] holds everything again, and listeners are told:
 * Android collects [state], iOS uses [addListener].
 */
class BudgetRepository(private val driver: SqlDriver) {
    private val db = BudgetDatabase(driver)
    private val _state = MutableStateFlow(load())
    private val listeners = mutableListOf<(BudgetState) -> Unit>()

    /** Everything, as of the latest change. */
    val state: StateFlow<BudgetState> = _state.asStateFlow()

    /** The current state, for callers that don't collect [state]. */
    val current: BudgetState get() = _state.value

    /** Called after every change with the new state. Returns a handle that removes it. */
    fun addListener(listener: (BudgetState) -> Unit): Subscription {
        listeners += listener
        return Subscription { listeners -= listener }
    }

    fun close() = driver.close()

    // MARK: - Recurring charges

    /** Adds the charge when its id is 0, else updates it. Returns its id. */
    fun saveCharge(charge: FixedCharge): Long = write {
        if (charge.id == 0L) {
            db.chargesQueries.insert(charge.title, charge.amount, charge.category.raw, charge.dayOfMonth.toLong(), charge.emoji)
            lastId()
        } else {
            db.chargesQueries.update(charge.title, charge.amount, charge.category.raw, charge.dayOfMonth.toLong(), charge.emoji, charge.id)
            charge.id
        }
    }

    fun deleteCharge(id: Long): Unit = write { db.chargesQueries.delete(id) }

    // MARK: - Income

    fun saveIncomeSource(source: IncomeSource): Long = write {
        if (source.id == 0L) {
            db.incomeQueries.insert(source.title, source.amount, source.emoji, source.isActive.toLong(), source.createdAt.millis)
            lastId()
        } else {
            db.incomeQueries.update(source.title, source.amount, source.emoji, source.isActive.toLong(), source.createdAt.millis, source.id)
            source.id
        }
    }

    fun deleteIncomeSource(id: Long): Unit = write { db.incomeQueries.delete(id) }

    /** Saves the lending itself; its history is left as it is. */
    fun saveLending(lending: Lending): Long = write {
        if (lending.id == 0L) {
            db.lendingsQueries.insert(lending.name, lending.emoji, lending.lent, lending.date.millis, lending.monthlyRepayment, lending.note)
            val id = lastId()
            lending.history.forEach { insertLendingSnapshot(id, it) }
            id
        } else {
            db.lendingsQueries.update(lending.name, lending.emoji, lending.lent, lending.date.millis, lending.monthlyRepayment, lending.note, lending.id)
            lending.id
        }
    }

    fun deleteLending(id: Long): Unit = write {
        db.lendingsQueries.deleteSnapshotsOf(id)
        db.lendingsQueries.delete(id)
    }

    fun saveLendingSnapshot(lendingId: Long, snapshot: LendingSnapshot): Long = write {
        if (snapshot.id == 0L) {
            insertLendingSnapshot(lendingId, snapshot)
        } else {
            db.lendingsQueries.updateSnapshot(snapshot.date.millis, snapshot.remaining, snapshot.note, snapshot.id)
            snapshot.id
        }
    }

    fun deleteLendingSnapshot(id: Long): Unit = write { db.lendingsQueries.deleteSnapshot(id) }

    // MARK: - Investments

    /** Saves the investment itself; its history is left as it is (new ones are added with theirs). */
    fun saveInvestment(investment: Investment): Long = write {
        if (investment.id == 0L) {
            db.investmentsQueries.insert(
                investment.name, investment.ticker, investment.kind.raw, investment.emoji,
                investment.createdAt.millis, investment.monthlyContribution,
            )
            val id = lastId()
            investment.history.forEach { insertValueSnapshot(id, it) }
            id
        } else {
            db.investmentsQueries.update(
                investment.name, investment.ticker, investment.kind.raw, investment.emoji,
                investment.createdAt.millis, investment.monthlyContribution, investment.id,
            )
            investment.id
        }
    }

    fun deleteInvestment(id: Long): Unit = write {
        db.investmentsQueries.deleteSnapshotsOf(id)
        db.investmentsQueries.delete(id)
    }

    /** The savings plan: how much goes to each investment every month (missing ids keep theirs). */
    fun saveSavingsPlan(contributions: Map<Long, Double>): Unit = write {
        contributions.forEach { (id, amount) -> db.investmentsQueries.updateContribution(maxOf(amount, 0.0), id) }
    }

    fun saveValueSnapshot(investmentId: Long, snapshot: ValueSnapshot): Long = write {
        if (snapshot.id == 0L) {
            insertValueSnapshot(investmentId, snapshot)
        } else {
            db.investmentsQueries.updateSnapshot(
                snapshot.date.millis, snapshot.value, snapshot.invested, snapshot.quantity, snapshot.unitPrice,
                snapshot.note, snapshot.id,
            )
            snapshot.id
        }
    }

    fun deleteValueSnapshot(id: Long): Unit = write { db.investmentsQueries.deleteSnapshot(id) }

    // MARK: - Home loan

    fun saveLoan(loan: Loan): Long = write {
        if (loan.id == 0L) {
            db.loansQueries.insert(loan.name, loan.emoji, loan.borrowed, loan.createdAt.millis)
            val id = lastId()
            loan.history.forEach { insertLoanSnapshot(id, it) }
            id
        } else {
            db.loansQueries.update(loan.name, loan.emoji, loan.borrowed, loan.createdAt.millis, loan.id)
            loan.id
        }
    }

    fun deleteLoan(id: Long): Unit = write {
        db.loansQueries.deleteSnapshotsOf(id)
        db.loansQueries.delete(id)
    }

    fun saveLoanSnapshot(loanId: Long, snapshot: LoanSnapshot): Long = write {
        if (snapshot.id == 0L) {
            insertLoanSnapshot(loanId, snapshot)
        } else {
            db.loansQueries.updateSnapshot(snapshot.date.millis, snapshot.remaining, snapshot.homeValue, snapshot.note, snapshot.id)
            snapshot.id
        }
    }

    fun deleteLoanSnapshot(id: Long): Unit = write { db.loansQueries.deleteSnapshot(id) }

    // MARK: - Snapshots

    /** Adds the snapshot when its id is 0, else replaces it (lines included). */
    fun saveSnapshot(snapshot: Snapshot): Long = write { upsertSnapshot(snapshot) }

    /**
     * Deletes a snapshot and, when `withValues`, the values recorded in its
     * month for investments, the home loan and money lent.
     */
    fun deleteSnapshot(id: Long, withValues: Boolean): Unit = write {
        val snapshot = _state.value.snapshot(id)
        if (withValues && snapshot != null) {
            val from = BudgetCalendar.startOfMonth(snapshot.date).millis
            val to = BudgetCalendar.endOfMonth(snapshot.date).millis + 999
            db.investmentsQueries.deleteSnapshotsInRange(from, to)
            db.loansQueries.deleteSnapshotsInRange(from, to)
            db.lendingsQueries.deleteSnapshotsInRange(from, to)
        }
        db.snapshotsQueries.deleteLinesOf(id)
        db.snapshotsQueries.delete(id)
    }

    /**
     * Takes the snapshot of a month: see [SnapshotRequest]. For the current
     * month, the amounts and switches of income lines and charges become the
     * current state; a past month keeps them to itself. The values of
     * investments and home loans replace the ones recorded that month.
     */
    fun takeSnapshot(request: SnapshotRequest): Long = write {
        val state = _state.value
        val plan = request.plan(state)
        val date = plan.date

        if (plan.isCurrentMonth) {
            for (entry in request.incomeSources) {
                db.incomeQueries.updateAmount(maxOf(entry.amount, 0.0), entry.isActive.toLong(), entry.id)
            }
            for (entry in request.charges) {
                db.chargesQueries.updateAmount(maxOf(entry.amount, 0.0), entry.id)
            }
        }

        for (entry in request.investments) {
            val investment = state.investment(entry.id) ?: continue
            val existing = investment.entryInMonthOf(date)
            val snapshot = ValueSnapshot(
                id = existing?.id ?: 0,
                date = date,
                value = entry.value,
                invested = investment.investedForSnapshot(date, savingIncluded = entry.id !in request.skippedSavings),
                quantity = entry.quantity,
                unitPrice = entry.unitPrice,
                note = existing?.note ?: "",
            )
            if (existing == null) {
                insertValueSnapshot(investment.id, snapshot)
            } else {
                db.investmentsQueries.updateSnapshot(
                    date.millis, snapshot.value, snapshot.invested, snapshot.quantity, snapshot.unitPrice,
                    snapshot.note, existing.id,
                )
            }
        }
        for (entry in request.loans) {
            val loan = state.loan(entry.id) ?: continue
            val existing = loan.entryInMonthOf(date)
            if (existing == null) {
                insertLoanSnapshot(loan.id, LoanSnapshot(date = date, remaining = entry.remaining, homeValue = entry.homeValue))
            } else {
                db.loansQueries.updateSnapshot(date.millis, entry.remaining, entry.homeValue, existing.note, existing.id)
            }
        }

        upsertSnapshot(
            Snapshot(
                id = plan.replaces?.id ?: 0,
                date = date,
                note = request.note,
                // Income comes only from the income lines now; `mainIncome` is
                // kept for snapshots taken before.
                mainIncome = 0.0,
                otherIncome = plan.sourcesIncome,
                repayments = plan.repayments,
                charges = plan.charges,
                savings = plan.savings,
                chargeLines = plan.chargeLines,
                incomeLines = plan.incomeLines,
            ),
        )
    }

    // MARK: - Whole database

    /** Removes everything. */
    fun deleteAll(): Unit = write {
        db.chargesQueries.deleteAll()
        db.incomeQueries.deleteAll()
        db.lendingsQueries.deleteAll()
        db.investmentsQueries.deleteAll()
        db.loansQueries.deleteAll()
        db.snapshotsQueries.deleteAll()
    }

    /** Adds everything in `state` (ids are ignored: new ones are given). */
    fun insertAll(state: BudgetState): Unit = write { insertAllNow(state) }

    fun meta(key: String): String? = db.metaQueries.get(key).executeAsOneOrNull()

    fun setMeta(key: String, value: String) = db.metaQueries.put(key, value)

    /** Runs `block` (calls to [importer]) in one transaction, and tells listeners once at the end. */
    internal fun <T> batch(block: () -> T): T = write(block)

    internal fun insertAllNow(state: BudgetState) {
        state.charges.forEach {
            db.chargesQueries.insert(it.title, it.amount, it.category.raw, it.dayOfMonth.toLong(), it.emoji)
        }
        state.incomeSources.forEach {
            db.incomeQueries.insert(it.title, it.amount, it.emoji, it.isActive.toLong(), it.createdAt.millis)
        }
        state.lendings.forEach { lending ->
            db.lendingsQueries.insert(lending.name, lending.emoji, lending.lent, lending.date.millis, lending.monthlyRepayment, lending.note)
            val id = lastId()
            lending.history.forEach { insertLendingSnapshot(id, it) }
        }
        state.investments.forEach { investment ->
            db.investmentsQueries.insert(
                investment.name, investment.ticker, investment.kind.raw, investment.emoji,
                investment.createdAt.millis, investment.monthlyContribution,
            )
            val id = lastId()
            investment.history.forEach { insertValueSnapshot(id, it) }
        }
        state.loans.forEach { loan ->
            db.loansQueries.insert(loan.name, loan.emoji, loan.borrowed, loan.createdAt.millis)
            val id = lastId()
            loan.history.forEach { insertLoanSnapshot(id, it) }
        }
        state.snapshots.forEach { upsertSnapshot(it.copy(id = 0)) }
    }

    // MARK: - Reading

    /** Reads everything from the database. */
    fun load(): BudgetState {
        val lendingHistory = db.lendingsQueries.selectAllSnapshots().executeAsList().groupBy({ it.lending_id }) {
            LendingSnapshot(it.id, it.date.instant, it.remaining, it.note)
        }
        val valueHistory = db.investmentsQueries.selectAllSnapshots().executeAsList().groupBy({ it.investment_id }) {
            ValueSnapshot(it.id, it.date.instant, it.value_, it.invested, it.quantity, it.unit_price, it.note)
        }
        val loanHistory = db.loansQueries.selectAllSnapshots().executeAsList().groupBy({ it.loan_id }) {
            LoanSnapshot(it.id, it.date.instant, it.remaining, it.home_value, it.note)
        }
        val lines = db.snapshotsQueries.selectAllLines().executeAsList().groupBy { it.snapshot_id }

        return BudgetState(
            charges = db.chargesQueries.selectAll().executeAsList().map {
                FixedCharge(it.id, it.title, it.amount, ChargeCategory.fromRaw(it.category), it.day_of_month.toInt(), it.emoji)
            },
            incomeSources = db.incomeQueries.selectAll().executeAsList().map {
                IncomeSource(it.id, it.title, it.amount, it.emoji, it.is_active != 0L, it.created_at.instant)
            },
            lendings = db.lendingsQueries.selectAll().executeAsList().map {
                Lending(it.id, it.name, it.emoji, it.lent, it.date.instant, it.monthly_repayment, it.note,
                    lendingHistory[it.id].orEmpty())
            },
            investments = db.investmentsQueries.selectAll().executeAsList().map {
                Investment(it.id, it.name, it.ticker, InvestmentKind.fromRaw(it.kind), it.emoji, it.created_at.instant,
                    it.monthly_contribution, valueHistory[it.id].orEmpty())
            },
            loans = db.loansQueries.selectAll().executeAsList().map {
                Loan(it.id, it.name, it.emoji, it.borrowed, it.created_at.instant, loanHistory[it.id].orEmpty())
            },
            snapshots = db.snapshotsQueries.selectAll().executeAsList().map { row ->
                val own = lines[row.id].orEmpty()
                Snapshot(
                    row.id, row.date.instant, row.note, row.main_income, row.other_income, row.repayments,
                    row.charges, row.savings,
                    chargeLines = own.filter { it.kind == CHARGE }.map { SnapshotLine(it.title, it.amount, it.category) },
                    incomeLines = own.filter { it.kind == INCOME }.map { SnapshotLine(it.title, it.amount, it.category) },
                )
            },
        )
    }

    // MARK: - Helpers

    private fun <T> write(block: () -> T): T {
        val result = db.transactionWithResult { block() }
        val state = load()
        _state.value = state
        listeners.toList().forEach { it(state) }
        return result
    }

    private fun lastId(): Long = db.metaQueries.lastId().executeAsOne()

    private fun insertLendingSnapshot(lendingId: Long, snapshot: LendingSnapshot): Long {
        db.lendingsQueries.insertSnapshot(lendingId, snapshot.date.millis, snapshot.remaining, snapshot.note)
        return lastId()
    }

    private fun insertValueSnapshot(investmentId: Long, snapshot: ValueSnapshot): Long {
        db.investmentsQueries.insertSnapshot(
            investmentId, snapshot.date.millis, snapshot.value, snapshot.invested, snapshot.quantity,
            snapshot.unitPrice, snapshot.note,
        )
        return lastId()
    }

    private fun insertLoanSnapshot(loanId: Long, snapshot: LoanSnapshot): Long {
        db.loansQueries.insertSnapshot(loanId, snapshot.date.millis, snapshot.remaining, snapshot.homeValue, snapshot.note)
        return lastId()
    }

    private fun upsertSnapshot(snapshot: Snapshot): Long {
        val q = db.snapshotsQueries
        val id = if (snapshot.id == 0L) {
            q.insert(snapshot.date.millis, snapshot.note, snapshot.mainIncome, snapshot.otherIncome, snapshot.repayments,
                snapshot.charges, snapshot.savings)
            lastId()
        } else {
            q.update(snapshot.date.millis, snapshot.note, snapshot.mainIncome, snapshot.otherIncome, snapshot.repayments,
                snapshot.charges, snapshot.savings, snapshot.id)
            q.deleteLinesOf(snapshot.id)
            snapshot.id
        }
        snapshot.chargeLines.forEachIndexed { i, line -> q.insertLine(id, CHARGE, i.toLong(), line.title, line.amount, line.category) }
        snapshot.incomeLines.forEachIndexed { i, line -> q.insertLine(id, INCOME, i.toLong(), line.title, line.amount, line.category) }
        return id
    }

    private companion object {
        const val CHARGE = "charge"
        const val INCOME = "income"
    }
}

/** Stops a listener added with [BudgetRepository.addListener]. */
class Subscription internal constructor(private val onCancel: () -> Unit) {
    fun cancel() = onCancel()
}

internal val Instant.millis: Long get() = toEpochMilliseconds()
internal val Long.instant: Instant get() = Instant.fromEpochMilliseconds(this)
private fun Boolean.toLong(): Long = if (this) 1L else 0L

package com.example.budget.core.data

import app.cash.sqldelight.db.SqlDriver
import com.example.budget.core.BudgetCalendar
import com.example.budget.core.BudgetState
import com.example.budget.core.charges.ChargesData
import com.example.budget.core.charges.FixedCharge
import com.example.budget.core.db.BudgetDatabase
import com.example.budget.core.income.IncomeData
import com.example.budget.core.income.IncomeSource
import com.example.budget.core.income.Lending
import com.example.budget.core.income.LendingSnapshot
import com.example.budget.core.income.LendingsData
import com.example.budget.core.snapshots.Snapshot
import com.example.budget.core.snapshots.SnapshotRequest
import com.example.budget.core.snapshots.SnapshotsData
import com.example.budget.core.wealth.Investment
import com.example.budget.core.wealth.InvestmentsData
import com.example.budget.core.wealth.Loan
import com.example.budget.core.wealth.LoanSnapshot
import com.example.budget.core.wealth.LoansData
import com.example.budget.core.wealth.ValueSnapshot
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * The one way in and out of the database, for both apps.
 *
 * Each feature reads and writes its own tables (`ChargesData`, `IncomeData`,
 * `LendingsData`, `InvestmentsData`, `LoansData`, `SnapshotsData`); this class
 * holds the state of everything and runs every change in a transaction,
 * including the ones that span features, like taking a snapshot.
 *
 * Every call is synchronous (the data is small) and runs in a transaction.
 * After each change, [state] holds everything again, and listeners are told:
 * Android collects [state], iOS uses [addListener].
 */
class BudgetRepository(private val driver: SqlDriver) {
    private val db = BudgetDatabase(driver)
    // Each feature's reads and writes; the repository holds the state and the transactions
    private val charges = ChargesData(db)
    private val income = IncomeData(db)
    private val lendings = LendingsData(db)
    private val investments = InvestmentsData(db)
    private val loans = LoansData(db)
    private val snapshots = SnapshotsData(db)
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
    fun saveCharge(charge: FixedCharge): Long = write { charges.save(charge) }

    fun deleteCharge(id: Long): Unit = write { charges.delete(id) }

    // MARK: - Income

    /** Adds the income line when its id is 0, else updates it. Returns its id. */
    fun saveIncomeSource(source: IncomeSource): Long = write { income.save(source) }

    fun deleteIncomeSource(id: Long): Unit = write { income.delete(id) }

    /** Saves the lending itself; its history is left as it is (a new one is added with its own). */
    fun saveLending(lending: Lending): Long = write { lendings.save(lending) }

    fun deleteLending(id: Long): Unit = write { lendings.delete(id) }

    fun saveLendingSnapshot(lendingId: Long, snapshot: LendingSnapshot): Long =
        write { lendings.saveSnapshot(lendingId, snapshot) }

    fun deleteLendingSnapshot(id: Long): Unit = write { lendings.deleteSnapshot(id) }

    // MARK: - Investments

    /** Saves the investment itself; its history is left as it is (a new one is added with its own). */
    fun saveInvestment(investment: Investment): Long = write { investments.save(investment) }

    fun deleteInvestment(id: Long): Unit = write { investments.delete(id) }

    /** The savings plan: how much goes to each investment every month (missing ids keep theirs). */
    fun saveSavingsPlan(contributions: Map<Long, Double>): Unit = write {
        contributions.forEach { (id, amount) -> investments.updateContribution(id, amount) }
    }

    fun saveValueSnapshot(investmentId: Long, snapshot: ValueSnapshot): Long =
        write { investments.saveSnapshot(investmentId, snapshot) }

    fun deleteValueSnapshot(id: Long): Unit = write { investments.deleteSnapshot(id) }

    // MARK: - Home loan

    /** Saves the loan itself; its history is left as it is (a new one is added with its own). */
    fun saveLoan(loan: Loan): Long = write { loans.save(loan) }

    fun deleteLoan(id: Long): Unit = write { loans.delete(id) }

    fun saveLoanSnapshot(loanId: Long, snapshot: LoanSnapshot): Long = write { loans.saveSnapshot(loanId, snapshot) }

    fun deleteLoanSnapshot(id: Long): Unit = write { loans.deleteSnapshot(id) }

    // MARK: - Snapshots (they span every feature)

    /** Adds the snapshot when its id is 0, else replaces it (lines included). */
    fun saveSnapshot(snapshot: Snapshot): Long = write { snapshots.save(snapshot) }

    /**
     * Deletes a snapshot and, when `withValues`, the values recorded in its
     * month for investments, the home loan and money lent.
     */
    fun deleteSnapshot(id: Long, withValues: Boolean): Unit = write {
        val snapshot = _state.value.snapshot(id)
        if (withValues && snapshot != null) {
            val from = BudgetCalendar.startOfMonth(snapshot.date).millis
            val to = BudgetCalendar.endOfMonth(snapshot.date).millis + 999
            investments.deleteSnapshotsInRange(from, to)
            loans.deleteSnapshotsInRange(from, to)
            lendings.deleteSnapshotsInRange(from, to)
        }
        snapshots.delete(id)
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
            request.incomeSources.forEach { income.updateAmount(it.id, it.amount, it.isActive) }
            request.charges.forEach { charges.updateAmount(it.id, it.amount) }
        }

        for (entry in request.investments) {
            val investment = state.investment(entry.id) ?: continue
            val existing = investment.entryInMonthOf(date)
            investments.saveSnapshot(
                investment.id,
                ValueSnapshot(
                    id = existing?.id ?: 0,
                    date = date,
                    value = entry.value,
                    invested = investment.investedForSnapshot(date, savingIncluded = entry.id !in request.skippedSavings),
                    quantity = entry.quantity,
                    unitPrice = entry.unitPrice,
                    note = existing?.note ?: "",
                ),
            )
        }
        for (entry in request.loans) {
            val loan = state.loan(entry.id) ?: continue
            val existing = loan.entryInMonthOf(date)
            loans.saveSnapshot(
                loan.id,
                LoanSnapshot(existing?.id ?: 0, date, entry.remaining, entry.homeValue, existing?.note ?: ""),
            )
        }

        snapshots.save(
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
        charges.deleteAll()
        income.deleteAll()
        lendings.deleteAll()
        investments.deleteAll()
        loans.deleteAll()
        snapshots.deleteAll()
    }

    /** Adds everything in `state` (ids are ignored: new ones are given). */
    fun insertAll(state: BudgetState): Unit = write { insertAllNow(state) }

    fun meta(key: String): String? = db.metaQueries.get(key).executeAsOneOrNull()

    fun setMeta(key: String, value: String) = db.metaQueries.put(key, value)

    /** Runs `block` in one transaction, and tells listeners once at the end. */
    internal fun <T> batch(block: () -> T): T = write(block)

    internal fun insertAllNow(state: BudgetState) {
        state.charges.forEach { charges.save(it.copy(id = 0)) }
        state.incomeSources.forEach { income.save(it.copy(id = 0)) }
        state.lendings.forEach { lendings.save(it.copy(id = 0)) }
        state.investments.forEach { investments.save(it.copy(id = 0)) }
        state.loans.forEach { loans.save(it.copy(id = 0)) }
        state.snapshots.forEach { snapshots.save(it.copy(id = 0)) }
    }

    // MARK: - Reading

    /** Reads everything from the database. */
    fun load(): BudgetState = BudgetState(
        charges = charges.load(),
        incomeSources = income.load(),
        lendings = lendings.load(),
        investments = investments.load(),
        loans = loans.load(),
        snapshots = snapshots.load(),
    )

    private fun <T> write(block: () -> T): T {
        val result = db.transactionWithResult { block() }
        val state = load()
        _state.value = state
        listeners.toList().forEach { it(state) }
        return result
    }
}

/** Stops a listener added with [BudgetRepository.addListener]. */
class Subscription internal constructor(private val onCancel: () -> Unit) {
    fun cancel() = onCancel()
}

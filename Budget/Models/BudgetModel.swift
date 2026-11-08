import BudgetCore
import Foundation
import Observation

/// Everything the screens show, kept up to date from the shared core's
/// repository, and every change the screens make. Shared with the views
/// through the environment.
@Observable
final class BudgetModel {
    private(set) var repository: BudgetRepository
    @ObservationIgnored private var subscription: BudgetCore.Subscription?

    /// Largest first.
    private(set) var charges: [FixedCharge] = []
    /// Oldest first.
    private(set) var incomeSources: [IncomeSource] = []
    /// Oldest first.
    private(set) var lendings: [Lending] = []
    /// By name.
    private(set) var investments: [Investment] = []
    /// By name.
    private(set) var loans: [Loan] = []
    /// Oldest first.
    private(set) var snapshots: [Snapshot] = []
    /// The shared core's state, for its calculations.
    private(set) var state: BudgetState

    init(repository: BudgetRepository) {
        self.repository = repository
        state = repository.current
        observe(repository)
    }

    deinit { subscription?.cancel() }

    /// Starts over on another repository (the demo data, when the UI tests ask).
    func replace(with repository: BudgetRepository) {
        subscription?.cancel()
        self.repository = repository
        observe(repository)
    }

    private func observe(_ repository: BudgetRepository) {
        apply(repository.current)
        subscription = repository.addListener { [weak self] state in
            self?.apply(state)
        }
    }

    private func apply(_ state: BudgetState) {
        self.state = state
        charges = state.charges.map(FixedCharge.init)
        incomeSources = state.incomeSources.map(IncomeSource.init)
        lendings = state.lendings.map(Lending.init)
        investments = state.investments.map(Investment.init)
        loans = state.loans.map(Loan.init)
        snapshots = state.snapshots.map(Snapshot.init)
    }

    // MARK: - Recurring charges

    func saveCharge(id: Int64?, title: String, amount: Double, category: ChargeCategory, emoji: String) {
        let dayOfMonth = charges.first { $0.id == id }?.core.dayOfMonth ?? 1
        _ = repository.saveCharge(charge: BudgetCore.FixedCharge(
            id: id ?? 0, title: title, amount: amount, category: category.core, dayOfMonth: dayOfMonth, emoji: emoji))
    }

    func delete(_ charge: FixedCharge) { repository.deleteCharge(id: charge.id) }

    // MARK: - Income

    func saveIncomeSource(id: Int64?, title: String, amount: Double, emoji: String, isActive: Bool) {
        let createdAt = incomeSources.first { $0.id == id }?.core.createdAt ?? BudgetCalendar.shared.now()
        _ = repository.saveIncomeSource(source: BudgetCore.IncomeSource(
            id: id ?? 0, title: title, amount: amount, emoji: emoji, isActive: isActive, createdAt: createdAt))
    }

    /// The main income of earlier versions, listed first.
    func addLegacySalary(amount: Double) {
        _ = repository.saveIncomeSource(source: BudgetCore.IncomeSource(
            id: 0, title: "Salary", amount: amount, emoji: "💼", isActive: true,
            createdAt: BudgetCalendar.shared.distantPast))
    }

    func delete(_ source: IncomeSource) { repository.deleteIncomeSource(id: source.id) }

    /// Saves money lent; `remaining` corrects its latest value when it has one.
    func saveLending(_ lending: Lending?, name: String, emoji: String, lent: Double, date: Date,
                     monthlyRepayment: Double, remaining: Double?) {
        let id = repository.saveLending(lending: BudgetCore.Lending(
            id: lending?.id ?? 0, name: name, emoji: emoji, lent: lent, date: date.instant,
            monthlyRepayment: monthlyRepayment, note: lending?.note ?? "", history: []))
        if let latest = lending?.latest, let remaining {
            _ = repository.saveLendingSnapshot(lendingId: id, snapshot: BudgetCore.LendingSnapshot(
                id: latest.id, date: latest.date.instant, remaining: max(remaining, 0), note: latest.note))
        }
    }

    func delete(_ lending: Lending) { repository.deleteLending(id: lending.id) }

    func saveLendingSnapshot(of lending: Lending, id: Int64?, date: Date, remaining: Double, note: String) {
        _ = repository.saveLendingSnapshot(lendingId: lending.id, snapshot: BudgetCore.LendingSnapshot(
            id: id ?? 0, date: date.instant, remaining: remaining, note: note))
    }

    func delete(_ snapshot: LendingSnapshot) { repository.deleteLendingSnapshot(id: snapshot.id) }

    // MARK: - Investments

    /// Saves an investment; a new one starts with `first` values when given.
    func saveInvestment(_ investment: Investment?, name: String, ticker: String, kind: InvestmentKind, emoji: String,
                        monthlyContribution: Double, first: BudgetCore.ValueSnapshot?) {
        _ = repository.saveInvestment(investment: BudgetCore.Investment(
            id: investment?.id ?? 0, name: name, ticker: ticker, kind: kind.core, emoji: emoji,
            createdAt: investment?.core.createdAt ?? BudgetCalendar.shared.now(),
            monthlyContribution: monthlyContribution,
            history: investment == nil ? [first].compactMap { $0 } : []))
    }

    func delete(_ investment: Investment) { repository.deleteInvestment(id: investment.id) }

    func setMonthlyContribution(_ amount: Double, of investment: Investment) {
        repository.saveSavingsPlan(contributions: [KotlinLong(value: investment.id): KotlinDouble(value: amount)])
    }

    func saveValueSnapshot(of investment: Investment, _ snapshot: BudgetCore.ValueSnapshot) {
        _ = repository.saveValueSnapshot(investmentId: investment.id, snapshot: snapshot)
    }

    func delete(_ snapshot: ValueSnapshot) { repository.deleteValueSnapshot(id: snapshot.id) }

    // MARK: - Home loan

    /// Saves a loan, and its latest values (a new loan's first ones) when given.
    func saveLoan(_ loan: Loan?, name: String, emoji: String, borrowed: Double, values: BudgetCore.LoanSnapshot?) {
        let id = repository.saveLoan(loan: BudgetCore.Loan(
            id: loan?.id ?? 0, name: name, emoji: emoji, borrowed: borrowed,
            createdAt: loan?.core.createdAt ?? BudgetCalendar.shared.now(), history: []))
        if let values {
            _ = repository.saveLoanSnapshot(loanId: id, snapshot: values)
        }
    }

    func delete(_ loan: Loan) { repository.deleteLoan(id: loan.id) }

    func saveLoanSnapshot(of loan: Loan, _ snapshot: BudgetCore.LoanSnapshot) {
        _ = repository.saveLoanSnapshot(loanId: loan.id, snapshot: snapshot)
    }

    func delete(_ snapshot: LoanSnapshot) { repository.deleteLoanSnapshot(id: snapshot.id) }

    // MARK: - Snapshots

    func take(_ request: SnapshotRequest) { _ = repository.takeSnapshot(request: request) }

    func delete(_ snapshot: Snapshot, withValues: Bool) {
        repository.deleteSnapshot(id: snapshot.id, withValues: withValues)
    }
}

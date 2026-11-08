import BudgetCore
import Foundation

// The app's data lives in the shared Kotlin core (shared/ at the root of the
// repository): the database, the calculations and the snapshot logic, the
// same code as the Android app. These types are read-only views over its
// models with Swift names and types (Date, Double?, the Swift enums), so the
// SwiftUI views read them as before. Changes go through `BudgetModel`.

/// The shared core's dates (`kotlin.time.Instant`).
typealias Instant = KotlinInstant

extension Date {
    init(_ instant: Instant) {
        self.init(timeIntervalSince1970: Double(instant.toEpochMilliseconds()) / 1000)
    }

    /// This date for the shared core.
    var instant: Instant {
        BudgetCalendar.shared.fromEpochMillis(millis: Int64((timeIntervalSince1970 * 1000).rounded()))
    }
}

extension Optional where Wrapped == Double {
    /// An optional number for the shared core.
    var kotlin: KotlinDouble? { map { KotlinDouble(value: $0) } }
}

extension KotlinDouble {
    var double: Double { doubleValue }
}

extension ChargeCategory {
    var core: BudgetCore.ChargeCategory { BudgetCore.ChargeCategory.companion.fromRaw(raw: rawValue) }
}

extension InvestmentKind {
    var core: BudgetCore.InvestmentKind { BudgetCore.InvestmentKind.companion.fromRaw(raw: rawValue) }
}

// MARK: - Recurring charges

struct FixedCharge: Identifiable, Hashable {
    let core: BudgetCore.FixedCharge

    var id: Int64 { core.id }
    var title: String { core.title }
    var amount: Double { core.amount }
    var categoryRaw: String { core.category.raw }
    var category: ChargeCategory { ChargeCategory(rawValue: categoryRaw) ?? .other }
    var emoji: String { core.emoji }
    var displayEmoji: String { core.displayEmoji }
}

// MARK: - Income

struct IncomeSource: Identifiable, Hashable {
    let core: BudgetCore.IncomeSource

    var id: Int64 { core.id }
    var title: String { core.title }
    var amount: Double { core.amount }
    var emoji: String { core.emoji }
    var isActive: Bool { core.isActive }
    var createdAt: Date { Date(core.createdAt) }
}

struct LendingSnapshot: Identifiable, Hashable {
    let core: BudgetCore.LendingSnapshot

    var id: Int64 { core.id }
    var date: Date { Date(core.date) }
    var remaining: Double { core.remaining }
    var note: String { core.note }
}

struct Lending: Identifiable, Hashable {
    let core: BudgetCore.Lending

    var id: Int64 { core.id }
    var name: String { core.name }
    var emoji: String { core.emoji }
    var lent: Double { core.lent }
    var date: Date { Date(core.date) }
    var monthlyRepayment: Double { core.monthlyRepayment }
    var note: String { core.note }
    var history: [LendingSnapshot] { core.history.map(LendingSnapshot.init) }

    /// Newest first.
    var sortedHistory: [LendingSnapshot] { core.sortedHistory.map(LendingSnapshot.init) }
    func entry(on date: Date) -> LendingSnapshot? { core.entryOn(date: date.instant).map(LendingSnapshot.init) }
    func entry(inMonthOf date: Date) -> LendingSnapshot? {
        core.entryInMonthOf(date: date.instant).map(LendingSnapshot.init)
    }
    func remaining(at date: Date) -> Double { core.remainingAt(date: date.instant) }

    var latest: LendingSnapshot? { core.latest.map(LendingSnapshot.init) }
    var remaining: Double { core.remaining }
    var repaid: Double { core.repaid }
    var repaidRatio: Double { core.repaidRatio }
    var isSettled: Bool { core.isSettled }
    var expectedThisMonth: Double { core.expectedThisMonth }
}

/// Monthly income: the income lines that are switched on, and the monthly repayments of money lent.
struct IncomeTotals {
    let sources: Double
    let repayments: Double

    init(sources: [IncomeSource], lendings: [Lending]) {
        let totals = BudgetCore.IncomeTotals(sources: sources.map(\.core), lendings: lendings.map(\.core))
        self.sources = totals.sources
        self.repayments = totals.repayments
    }

    var total: Double { sources + repayments }
}

// MARK: - Investments

struct ValueSnapshot: Identifiable, Hashable {
    let core: BudgetCore.ValueSnapshot

    var id: Int64 { core.id }
    var date: Date { Date(core.date) }
    var value: Double { core.value }
    var invested: Double { core.invested }
    var quantity: Double? { core.quantity?.doubleValue }
    var unitPrice: Double? { core.unitPrice?.doubleValue }
    var note: String { core.note }
    var gain: Double { core.gain }
    var tracksUnits: Bool { core.tracksUnits }
}

struct Investment: Identifiable, Hashable {
    let core: BudgetCore.Investment

    var id: Int64 { core.id }
    var name: String { core.name }
    var ticker: String { core.ticker }
    var kind: InvestmentKind { InvestmentKind(rawValue: core.kind.raw) ?? .other }
    var emoji: String { core.emoji }
    var createdAt: Date { Date(core.createdAt) }
    var monthlyContribution: Double { core.monthlyContribution }
    var history: [ValueSnapshot] { core.history.map(ValueSnapshot.init) }

    var displayEmoji: String { core.displayEmoji }
    /// Newest first.
    var sortedHistory: [ValueSnapshot] { core.sortedHistory.map(ValueSnapshot.init) }
    func snapshot(at date: Date) -> ValueSnapshot? { core.snapshotAt(date: date.instant).map(ValueSnapshot.init) }
    func entry(on date: Date) -> ValueSnapshot? { core.entryOn(date: date.instant).map(ValueSnapshot.init) }
    func entry(inMonthOf date: Date) -> ValueSnapshot? {
        core.entryInMonthOf(date: date.instant).map(ValueSnapshot.init)
    }

    var latest: ValueSnapshot? { core.latest.map(ValueSnapshot.init) }
    var currentValue: Double { core.currentValue }
    var investedAmount: Double { core.investedAmount }
    var gain: Double { core.gain }
    var gainRatio: Double { core.gainRatio }
}

// MARK: - Home loan

struct LoanSnapshot: Identifiable, Hashable {
    let core: BudgetCore.LoanSnapshot

    var id: Int64 { core.id }
    var date: Date { Date(core.date) }
    var remaining: Double { core.remaining }
    var homeValue: Double { core.homeValue }
    var note: String { core.note }
}

struct Loan: Identifiable, Hashable {
    let core: BudgetCore.Loan

    var id: Int64 { core.id }
    var name: String { core.name }
    var emoji: String { core.emoji }
    var borrowed: Double { core.borrowed }
    var createdAt: Date { Date(core.createdAt) }
    var history: [LoanSnapshot] { core.history.map(LoanSnapshot.init) }

    /// Newest first.
    var sortedHistory: [LoanSnapshot] { core.sortedHistory.map(LoanSnapshot.init) }
    func entry(on date: Date) -> LoanSnapshot? { core.entryOn(date: date.instant).map(LoanSnapshot.init) }

    var latest: LoanSnapshot? { core.latest.map(LoanSnapshot.init) }
    var remaining: Double { core.remaining }
    var repaid: Double { core.repaid }
    var repaidRatio: Double { core.repaidRatio }
    var homeValue: Double { core.homeValue }
    var equity: Double { core.equity }
    var equityRatio: Double { core.equityRatio }
}

// MARK: - Snapshots

/// A charge or an income as it was when a snapshot was taken.
struct SnapshotLine: Hashable {
    var title: String
    var amount: Double
    /// `ChargeCategory` raw value; empty for income.
    var category: String = ""

    init(title: String, amount: Double, category: String = "") {
        self.title = title
        self.amount = amount
        self.category = category
    }

    init(_ core: BudgetCore.SnapshotLine) {
        self.init(title: core.title, amount: core.amount, category: core.category)
    }
}

/// The whole picture for a month: one snapshot per month.
struct Snapshot: Identifiable, Hashable {
    let core: BudgetCore.Snapshot

    var id: Int64 { core.id }
    var date: Date { Date(core.date) }
    var note: String { core.note }
    var mainIncome: Double { core.mainIncome }
    var otherIncome: Double { core.otherIncome }
    var repayments: Double { core.repayments }
    var charges: Double { core.charges }
    var savings: Double { core.savings }
    var chargeLines: [SnapshotLine] { core.chargeLines.map(SnapshotLine.init) }
    var incomeLines: [SnapshotLine] { core.incomeLines.map(SnapshotLine.init) }

    /// First day of the month it stands for.
    var month: Date { Date(core.month) }
    /// Everything recorded up to the end of its month counts.
    var endOfMonth: Date { Date(core.endOfMonth) }
    var income: Double { core.income }
    /// What was free to spend each month.
    var left: Double { core.left }
    var savingsRate: Double { core.savingsRate }

    /// Whether the current month already has its snapshot.
    static func isTaken(thisMonthIn snapshots: [Snapshot]) -> Bool {
        BudgetCore.Snapshot.companion.isTakenThisMonth(snapshots: snapshots.map(\.core), now: BudgetCalendar.shared.now())
    }
}

// MARK: - Wealth and trends

/// Investments, home equity and money lent on a given day.
struct WealthPoint: Identifiable {
    var date: Date
    let investments: Double
    let invested: Double
    let homeEquity: Double
    let lent: Double
    var id: Date { date }

    var netWorth: Double { investments + homeEquity + lent }

    init(_ core: BudgetCore.WealthPoint) {
        date = Date(core.date)
        investments = core.investments
        invested = core.invested
        homeEquity = core.homeEquity
        lent = core.lent
    }
}

enum Wealth {
    /// Everything counted with its latest values on or before `date` (everything recorded when nil).
    static func point(at date: Date? = nil, investments: [Investment], loans: [Loan], lendings: [Lending]) -> WealthPoint {
        let when = date?.instant ?? BudgetCalendar.shared.distantFuture
        return WealthPoint(BudgetCore.Wealth.shared.pointAt(
            date: when, investments: investments.map(\.core), loans: loans.map(\.core), lendings: lendings.map(\.core)))
    }

    /// One point per day on which something was recorded.
    static func points(investments: [Investment], loans: [Loan], lendings: [Lending]) -> [WealthPoint] {
        BudgetCore.Wealth.shared.points(
            investments: investments.map(\.core), loans: loans.map(\.core), lendings: lendings.map(\.core)
        ).map(WealthPoint.init)
    }
}

struct HistoryPoint: Identifiable {
    let date: Date
    let value: Double
    let invested: Double
    var id: Date { date }
}

enum History {
    /// One point per day with a snapshot; each position counts with its latest snapshot on that day.
    static func points(for investments: [Investment]) -> [HistoryPoint] {
        BudgetCore.History.shared.points(investments: investments.map(\.core)).map {
            HistoryPoint(date: Date($0.date), value: $0.value, invested: $0.invested)
        }
    }
}

struct SavingsPoint: Identifiable {
    let month: Date
    let investment: String
    let amount: Double
    var id: String { "\(month.timeIntervalSince1970)-\(investment)" }
}

enum Savings {
    /// Money saved each month, per position: the change in "invested so far" between two snapshots.
    static func monthly(for investments: [Investment], months: Int = 12) -> [SavingsPoint] {
        BudgetCore.Savings.shared.monthly(
            investments: investments.map(\.core), months: Int32(months), now: BudgetCalendar.shared.now()
        ).map { SavingsPoint(month: Date($0.month), investment: $0.investment, amount: $0.amount) }
    }
}

import Foundation
import SwiftData

/// Income on top of the main salary (freelance work, a lodger, a bonus...).
/// Switched off when it doesn't come in, so it stays listed without counting.
@Model
final class IncomeSource {
    var title: String = ""
    var amount: Double = 0
    var emoji: String = "💼"
    var isActive: Bool = true
    var createdAt: Date = Date.now

    init(title: String, amount: Double, emoji: String = "💼", isActive: Bool = true) {
        self.title = title
        self.amount = amount
        self.emoji = emoji
        self.isActive = isActive
        self.createdAt = .now
    }
}

/// Money lent to someone, followed like the home loan: what's left
/// to repay is recorded from time to time.
@Model
final class Lending {
    /// Who the money was lent to.
    var name: String = ""
    var emoji: String = "💸"
    /// Amount lent at the start.
    var lent: Double = 0
    var date: Date = Date.now
    /// What they pay back each month, counted as income until it's all repaid.
    /// 0 when there's no fixed amount.
    var monthlyRepayment: Double = 0
    var note: String = ""

    @Relationship(deleteRule: .cascade, inverse: \LendingSnapshot.lending)
    var history: [LendingSnapshot] = []

    init(name: String, emoji: String = "💸", lent: Double, date: Date = .now, monthlyRepayment: Double = 0) {
        self.name = name
        self.emoji = emoji
        self.lent = lent
        self.date = date
        self.monthlyRepayment = monthlyRepayment
    }

    /// Newest first.
    var sortedHistory: [LendingSnapshot] { history.sorted { $0.date > $1.date } }

    /// What was left to repay on the same day as `date`, if recorded.
    func entry(on date: Date) -> LendingSnapshot? {
        history.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// The latest value recorded in the same month as `date`, if any.
    func entry(inMonthOf date: Date) -> LendingSnapshot? {
        history.filter { Calendar.current.isDate($0.date, inSameMonthAs: date) }.max { $0.date < $1.date }
    }

    /// What was still owed at `date`: nothing before the money was lent.
    func remaining(at date: Date) -> Double {
        guard self.date <= date else { return 0 }
        let snapshot = history.filter { $0.date <= date }.max { $0.date < $1.date }
        return max(snapshot?.remaining ?? lent, 0)
    }

    var latest: LendingSnapshot? { history.max { $0.date < $1.date } }
    var remaining: Double { max(latest?.remaining ?? lent, 0) }
    var repaid: Double { max(lent - remaining, 0) }
    var repaidRatio: Double { lent > 0 ? min(repaid / lent, 1) : 0 }
    var isSettled: Bool { lent > 0 && remaining <= 0.005 }
    /// What comes in this month: the monthly repayment, never more than what's left.
    var expectedThisMonth: Double { min(monthlyRepayment, remaining) }
}

@Model
final class LendingSnapshot {
    var date: Date = Date.now
    /// What's still owed on that date.
    var remaining: Double = 0
    var note: String = ""
    var lending: Lending?

    init(date: Date = .now, remaining: Double = 0, note: String = "") {
        self.date = date
        self.remaining = remaining
        self.note = note
    }
}

/// Monthly income: the main income, other income that's switched on,
/// and the monthly repayments of money lent.
struct IncomeTotals {
    let main: Double
    let other: Double
    let repayments: Double

    init(main: Double, sources: [IncomeSource], lendings: [Lending]) {
        self.main = main
        self.other = sources.filter(\.isActive).reduce(0) { $0 + $1.amount }
        self.repayments = lendings.reduce(0) { $0 + $1.expectedThisMonth }
    }

    var total: Double { main + other + repayments }
}

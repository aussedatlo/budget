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

/// Money lent to someone, followed through the repayments they make.
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

    @Relationship(deleteRule: .cascade, inverse: \Repayment.lending)
    var repayments: [Repayment] = []

    init(name: String, emoji: String = "💸", lent: Double, date: Date = .now, monthlyRepayment: Double = 0) {
        self.name = name
        self.emoji = emoji
        self.lent = lent
        self.date = date
        self.monthlyRepayment = monthlyRepayment
    }

    /// Newest first.
    var sortedRepayments: [Repayment] { repayments.sorted { $0.date > $1.date } }

    var repaid: Double { repayments.reduce(0) { $0 + $1.amount } }
    var remaining: Double { max(lent - repaid, 0) }
    var repaidRatio: Double { lent > 0 ? min(repaid / lent, 1) : 0 }
    var isSettled: Bool { lent > 0 && remaining <= 0.005 }
    /// What comes in this month: the monthly repayment, never more than what's left.
    var expectedThisMonth: Double { min(monthlyRepayment, remaining) }
}

@Model
final class Repayment {
    var date: Date = Date.now
    var amount: Double = 0
    var note: String = ""
    var lending: Lending?

    init(date: Date = .now, amount: Double = 0, note: String = "") {
        self.date = date
        self.amount = amount
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

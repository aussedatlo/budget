import Foundation
import SwiftData

/// A home loan, followed through snapshots of what's left to repay
/// and what the home is worth.
@Model
final class Loan {
    var name: String = ""
    var emoji: String = "🏠"
    /// Amount borrowed at the start.
    var borrowed: Double = 0
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \LoanSnapshot.loan)
    var history: [LoanSnapshot] = []

    init(name: String, emoji: String = "🏠", borrowed: Double) {
        self.name = name
        self.emoji = emoji
        self.borrowed = borrowed
        self.createdAt = .now
    }

    /// Newest first.
    var sortedHistory: [LoanSnapshot] { history.sorted { $0.date > $1.date } }

    func snapshot(at date: Date = .distantFuture) -> LoanSnapshot? {
        history.filter { $0.date <= date }.max { $0.date < $1.date }
    }

    var latest: LoanSnapshot? { snapshot() }
    var remaining: Double { latest?.remaining ?? borrowed }
    var repaid: Double { max(borrowed - remaining, 0) }
    var repaidRatio: Double { borrowed > 0 ? min(repaid / borrowed, 1) : 0 }
    var homeValue: Double { latest?.homeValue ?? 0 }
    /// The part of the home that is really ours.
    var equity: Double { homeValue - remaining }
    var equityRatio: Double { homeValue > 0 ? max(min(equity / homeValue, 1), 0) : 0 }
}

@Model
final class LoanSnapshot {
    var date: Date = Date.now
    /// Capital left to repay, as on the bank statement.
    var remaining: Double = 0
    /// Estimated value of the home.
    var homeValue: Double = 0
    var note: String = ""
    var loan: Loan?

    init(date: Date = .now, remaining: Double = 0, homeValue: Double = 0, note: String = "") {
        self.date = date
        self.remaining = remaining
        self.homeValue = homeValue
        self.note = note
    }
}

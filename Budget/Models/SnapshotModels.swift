import Foundation
import SwiftData

/// A charge or an income as it was when a snapshot was taken.
struct SnapshotLine: Codable, Hashable {
    var title: String
    var amount: Double
    /// `ChargeCategory` raw value; empty for income.
    var category: String = ""
}

/// The whole picture on a given day. The monthly budget (income, recurring
/// charges, planned savings) is stored here; investments, the home loan and
/// money lent record their values of that day in their own history.
@Model
final class Snapshot {
    var date: Date = Date.now
    var note: String = ""
    var mainIncome: Double = 0
    var otherIncome: Double = 0
    /// Monthly repayments of money lent.
    var repayments: Double = 0
    var charges: Double = 0
    /// Planned monthly savings.
    var savings: Double = 0
    /// `[SnapshotLine]` as JSON.
    var chargeLinesData: Data = Data()
    var incomeLinesData: Data = Data()

    init(date: Date = .now) {
        self.date = date
    }

    var income: Double { mainIncome + otherIncome + repayments }
    /// What was free to spend each month.
    var left: Double { income - charges - savings }
    var savingsRate: Double { income > 0 ? savings / income : 0 }

    var chargeLines: [SnapshotLine] {
        get { Self.decode(chargeLinesData) }
        set { chargeLinesData = Self.encode(newValue) }
    }

    var incomeLines: [SnapshotLine] {
        get { Self.decode(incomeLinesData) }
        set { incomeLinesData = Self.encode(newValue) }
    }

    /// Copies the monthly budget as it is now.
    func capture(mainIncome: Double, sources: [IncomeSource], lendings: [Lending],
                 charges: [FixedCharge], investments: [Investment]) {
        let totals = IncomeTotals(main: mainIncome, sources: sources, lendings: lendings)
        self.mainIncome = totals.main
        self.otherIncome = totals.other
        self.repayments = totals.repayments
        self.charges = charges.reduce(0) { $0 + $1.amount }
        self.savings = investments.reduce(0) { $0 + $1.monthlyContribution }

        chargeLines = charges.map { SnapshotLine(title: $0.title, amount: $0.amount, category: $0.categoryRaw) }
        var lines = [SnapshotLine(title: "Main income", amount: totals.main)]
        for source in sources where source.isActive {
            lines.append(SnapshotLine(title: source.title, amount: source.amount))
        }
        for lending in lendings where lending.expectedThisMonth > 0 {
            lines.append(SnapshotLine(title: "Repaid by \(lending.name)", amount: lending.expectedThisMonth))
        }
        incomeLines = lines
    }

    private static func decode(_ data: Data) -> [SnapshotLine] {
        (try? JSONDecoder().decode([SnapshotLine].self, from: data)) ?? []
    }

    private static func encode(_ lines: [SnapshotLine]) -> Data {
        (try? JSONEncoder().encode(lines)) ?? Data()
    }
}

// MARK: - Wealth

/// Investments, home equity and money lent on a given day.
struct WealthPoint: Identifiable {
    var date: Date
    let investments: Double
    let invested: Double
    let homeEquity: Double
    let lent: Double
    var id: Date { date }

    var netWorth: Double { investments + homeEquity + lent }
}

enum Wealth {
    /// Everything counted with its latest values on or before `date`.
    static func point(at date: Date = .distantFuture, investments: [Investment],
                      loans: [Loan], lendings: [Lending]) -> WealthPoint {
        let values = investments.compactMap { $0.snapshot(at: date) }
        let homes = loans.compactMap { $0.snapshot(at: date) }
        return WealthPoint(
            date: date,
            investments: values.reduce(0) { $0 + $1.value },
            invested: values.reduce(0) { $0 + $1.invested },
            homeEquity: homes.reduce(0) { $0 + $1.homeValue - $1.remaining },
            lent: lendings.reduce(0) { $0 + $1.remaining(at: date) }
        )
    }

    /// One point per day on which something was recorded.
    static func points(investments: [Investment], loans: [Loan], lendings: [Lending]) -> [WealthPoint] {
        let calendar = Calendar.current
        var dates: [Date] = investments.flatMap { $0.history.map(\.date) }
        dates += loans.flatMap { $0.history.map(\.date) }
        dates += lendings.flatMap { [$0.date] + $0.history.map(\.date) }
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        return days.sorted().map { day in
            var wealth = point(at: calendar.endOfDay(for: day), investments: investments,
                               loans: loans, lendings: lendings)
            wealth.date = day
            return wealth
        }
    }
}

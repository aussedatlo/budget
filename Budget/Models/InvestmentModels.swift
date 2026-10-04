import Foundation
import SwiftData
import SwiftUI

enum InvestmentKind: String, CaseIterable, Identifiable {
    case stock = "Stock"
    case etf = "ETF"
    case fund = "Fund"
    case crypto = "Crypto"
    case metal = "Precious metal"
    case savings = "Savings"
    case realEstate = "Real estate"
    case other = "Other"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .stock: "📈"
        case .etf: "🌍"
        case .fund: "💼"
        case .crypto: "🪙"
        case .metal: "🥇"
        case .savings: "🐷"
        case .realEstate: "🏠"
        case .other: "💎"
        }
    }

    var color: Color {
        switch self {
        case .stock: Theme.sky
        case .etf: Theme.mint
        case .fund: Theme.lavender
        case .crypto: Theme.peach
        case .metal: Theme.butter
        case .savings: Theme.pink
        case .realEstate: Theme.peach
        case .other: Theme.lavender
        }
    }
}

/// A position (ETF, gold coins, crypto, savings account...).
/// Its history records, from time to time, what it's worth and how much
/// money was put in so far.
@Model
final class Investment {
    var name: String = ""
    var ticker: String = ""
    var kindRaw: String = InvestmentKind.etf.rawValue
    var emoji: String = ""
    var createdAt: Date = Date.now
    /// Savings plan: money added every month (0 = none).
    var monthlyContribution: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \ValueSnapshot.investment)
    var history: [ValueSnapshot] = []

    init(name: String, ticker: String = "", kind: InvestmentKind = .etf, emoji: String = "") {
        self.name = name
        self.ticker = ticker
        self.kindRaw = kind.rawValue
        self.emoji = emoji
        self.createdAt = .now
    }

    var kind: InvestmentKind {
        get { InvestmentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var displayEmoji: String { emoji.isEmpty ? kind.emoji : emoji }

    /// Newest first.
    var sortedHistory: [ValueSnapshot] { history.sorted { $0.date > $1.date } }

    /// The most recent snapshot on or before a date.
    func snapshot(at date: Date = .distantFuture) -> ValueSnapshot? {
        history.filter { $0.date <= date }.max { $0.date < $1.date }
    }

    /// The values recorded on the same day as `date`, if any.
    func entry(on date: Date) -> ValueSnapshot? {
        history.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// The latest values recorded in the same month as `date`, if any.
    func entry(inMonthOf date: Date) -> ValueSnapshot? {
        history.filter { Calendar.current.isDate($0.date, inSameMonthAs: date) }.max { $0.date < $1.date }
    }

    var latest: ValueSnapshot? { snapshot() }
    var currentValue: Double { latest?.value ?? 0 }
    var investedAmount: Double { latest?.invested ?? 0 }
    var gain: Double { currentValue - investedAmount }
    var gainRatio: Double { investedAmount > 0 ? gain / investedAmount : 0 }

    /// "Invested so far" for the snapshot of `date`'s month: the amount
    /// recorded before that month plus the savings plan for each month since,
    /// this month's saving left out when it's switched off. Retaking a month
    /// starts again from the month before, so the saving isn't added twice,
    /// but an amount corrected by hand on the Wealth tab that month is kept.
    func investedForSnapshot(at date: Date, savingIncluded: Bool) -> Double {
        let calendar = Calendar.current
        let month = calendar.monthInterval(for: date).start
        let existing = entry(inMonthOf: date)
        guard let previous = history.filter({ $0.date < month }).max(by: { $0.date < $1.date }) else {
            return existing?.invested ?? latest?.invested ?? 0
        }
        let months = calendar.monthsBetween(previous.date, date)
        let withSaving = previous.invested + monthlyContribution * Double(months)
        let withoutSaving = withSaving - monthlyContribution
        if let existing, abs(existing.invested - withSaving) > 0.005, abs(existing.invested - withoutSaving) > 0.005 {
            return existing.invested
        }
        return savingIncluded ? withSaving : withoutSaving
    }
}

/// What a position is worth at a date, and how much was put in so far.
/// Quantity and unit price are optional; when both are set, value = quantity × unit price.
@Model
final class ValueSnapshot {
    var date: Date = Date.now
    var value: Double = 0
    var invested: Double = 0
    var quantity: Double?
    var unitPrice: Double?
    var note: String = ""
    var investment: Investment?

    init(date: Date = .now, value: Double = 0, invested: Double = 0,
         quantity: Double? = nil, unitPrice: Double? = nil, note: String = "") {
        self.date = date
        self.value = value
        self.invested = invested
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.note = note
    }

    var gain: Double { value - invested }
    var tracksUnits: Bool { quantity != nil && unitPrice != nil }
}

// MARK: - History

struct HistoryPoint: Identifiable {
    let date: Date
    let value: Double
    let invested: Double
    var id: Date { date }
}

enum History {
    /// One point per day with a snapshot; each position counts with its
    /// latest snapshot on that day.
    static func points(for investments: [Investment]) -> [HistoryPoint] {
        let calendar = Calendar.current
        let days = Set(investments.flatMap { $0.history.map { calendar.startOfDay(for: $0.date) } })
        return days.sorted().map { day in
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: day)!.addingTimeInterval(-1)
            let snapshots = investments.compactMap { $0.snapshot(at: endOfDay) }
            return HistoryPoint(
                date: day,
                value: snapshots.reduce(0) { $0 + $1.value },
                invested: snapshots.reduce(0) { $0 + $1.invested }
            )
        }
    }
}

// MARK: - Savings

struct SavingsPoint: Identifiable {
    let month: Date
    let investment: String
    let amount: Double
    var id: String { "\(month.timeIntervalSince1970)-\(investment)" }
}

enum Savings {
    /// Money saved each month, per position: the change in "invested so far"
    /// between two snapshots, counted in the month of the later one.
    /// Market moves don't count, only money put in or taken out.
    static func monthly(for investments: [Investment], months: Int = 12) -> [SavingsPoint] {
        let calendar = Calendar.current
        let firstMonth = calendar.date(byAdding: .month, value: -(months - 1),
                                       to: calendar.monthInterval(for: .now).start)!
        var totals: [Date: [String: Double]] = [:]
        for investment in investments {
            let history = investment.history.sorted { $0.date < $1.date }
            for (previous, snapshot) in zip(history, history.dropFirst()) {
                let month = calendar.monthInterval(for: snapshot.date).start
                guard month >= firstMonth else { continue }
                let added = snapshot.invested - previous.invested
                guard added != 0 else { continue }
                totals[month, default: [:]][investment.name, default: 0] += added
            }
        }
        return totals.keys.sorted().flatMap { month in
            totals[month]!.sorted { $0.key < $1.key }.map {
                SavingsPoint(month: month, investment: $0.key, amount: $0.value)
            }
        }
    }
}

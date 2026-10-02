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
/// It is followed through snapshots: from time to time, what it's worth
/// and how much money was put in so far.
@Model
final class Investment {
    var name: String = ""
    var ticker: String = ""
    var kindRaw: String = InvestmentKind.etf.rawValue
    var emoji: String = ""
    var createdAt: Date = Date.now

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

    var latest: ValueSnapshot? { snapshot() }
    var currentValue: Double { latest?.value ?? 0 }
    var investedAmount: Double { latest?.invested ?? 0 }
    var gain: Double { currentValue - investedAmount }
    var gainRatio: Double { investedAmount > 0 ? gain / investedAmount : 0 }
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

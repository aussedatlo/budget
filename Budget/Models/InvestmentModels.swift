import Foundation
import SwiftData

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

    var icon: String {
        switch self {
        case .stock: "building.columns"
        case .etf: "chart.pie"
        case .fund: "briefcase"
        case .crypto: "bitcoinsign.circle"
        case .metal: "cube.fill"
        case .savings: "banknote"
        case .realEstate: "house"
        case .other: "square.stack.3d.up"
        }
    }
}

/// A position (stock, ETF, crypto, savings account...).
/// Its history is made of trades (money in / out) and price snapshots.
@Model
final class Investment {
    var name: String = ""
    var ticker: String = ""
    var kindRaw: String = InvestmentKind.etf.rawValue
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Trade.investment)
    var trades: [Trade] = []

    @Relationship(deleteRule: .cascade, inverse: \PriceSnapshot.investment)
    var snapshots: [PriceSnapshot] = []

    init(name: String, ticker: String = "", kind: InvestmentKind = .etf) {
        self.name = name
        self.ticker = ticker
        self.kindRaw = kind.rawValue
        self.createdAt = .now
    }

    var kind: InvestmentKind {
        get { InvestmentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    // MARK: - Metrics

    /// Units held at a given date.
    func quantity(at date: Date = .distantFuture) -> Double {
        trades.filter { $0.date <= date }.reduce(0) { $0 + $1.signedQuantity }
    }

    /// Money put in minus money taken out, fees included.
    func netInvested(at date: Date = .distantFuture) -> Double {
        trades.filter { $0.date <= date }.reduce(0) { $0 + $1.cashFlow }
    }

    /// Most recent known unit price (snapshot or trade) at a given date.
    func price(at date: Date = .distantFuture) -> Double? {
        let snapshot = snapshots.filter { $0.date <= date }.max { $0.date < $1.date }
        let trade = trades.filter { $0.date <= date }.max { $0.date < $1.date }
        switch (snapshot, trade) {
        case let (s?, t?): return s.date >= t.date ? s.unitPrice : t.unitPrice
        case let (s?, nil): return s.unitPrice
        case let (nil, t?): return t.unitPrice
        default: return nil
        }
    }

    func value(at date: Date = .distantFuture) -> Double {
        quantity(at: date) * (price(at: date) ?? 0)
    }

    var currentQuantity: Double { quantity() }
    var currentValue: Double { value() }
    var investedAmount: Double { netInvested() }
    var gain: Double { currentValue - investedAmount }
    var gainRatio: Double { investedAmount > 0 ? gain / investedAmount : 0 }

    /// Weighted average purchase price (fees included).
    var averageBuyPrice: Double? {
        let buys = trades.filter { !$0.isSale }
        let quantity = buys.reduce(0) { $0 + $1.quantity }
        guard quantity > 0 else { return nil }
        return buys.reduce(0) { $0 + $1.cashFlow } / quantity
    }

    var lastPriceDate: Date? {
        (snapshots.map(\.date) + trades.map(\.date)).max()
    }

    var sortedTrades: [Trade] { trades.sorted { $0.date > $1.date } }
    var sortedSnapshots: [PriceSnapshot] { snapshots.sorted { $0.date > $1.date } }
}

/// A buy or a sell.
@Model
final class Trade {
    var date: Date = Date.now
    var quantity: Double = 0
    var unitPrice: Double = 0
    var fees: Double = 0
    var isSale: Bool = false
    var note: String = ""
    var investment: Investment?

    init(date: Date = .now, quantity: Double = 0, unitPrice: Double = 0,
         fees: Double = 0, isSale: Bool = false, note: String = "") {
        self.date = date
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.fees = fees
        self.isSale = isSale
        self.note = note
    }

    var grossAmount: Double { quantity * unitPrice }
    var signedQuantity: Double { isSale ? -quantity : quantity }
    /// Positive when money goes into the investment, negative when it comes out.
    var cashFlow: Double { isSale ? -(grossAmount - fees) : grossAmount + fees }
}

/// The price of one unit at a point in time.
@Model
final class PriceSnapshot {
    var date: Date = Date.now
    var unitPrice: Double = 0
    var note: String = ""
    var investment: Investment?

    init(date: Date = .now, unitPrice: Double = 0, note: String = "") {
        self.date = date
        self.unitPrice = unitPrice
        self.note = note
    }
}

// MARK: - History

struct HistoryPoint: Identifiable {
    let date: Date
    let value: Double
    let invested: Double
    var id: Date { date }
}

enum History {
    /// One point per day on which something happened (trade or snapshot).
    static func points(for investments: [Investment]) -> [HistoryPoint] {
        let calendar = Calendar.current
        let days = Set(
            investments
                .flatMap { $0.trades.map(\.date) + $0.snapshots.map(\.date) }
                .map { calendar.startOfDay(for: $0) }
        )
        return days.sorted().map { day in
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: day)!.addingTimeInterval(-1)
            return HistoryPoint(
                date: day,
                value: investments.reduce(0) { $0 + $1.value(at: endOfDay) },
                invested: investments.reduce(0) { $0 + $1.netInvested(at: endOfDay) }
            )
        }
    }
}

import Foundation
import SwiftData

/// Sample data used by the UI tests (launch argument `-demo-data`).
/// Stored in memory only: it never touches the user's real data.
enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-data")
    }

    static func makeContainer(for schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        seed(context)
        try? context.save()
        return container
    }

    private static func seed(_ context: ModelContext) {
        let calendar = Calendar.current
        let now = Date.now
        let monthStart = calendar.monthInterval(for: now).start

        func monthsAgo(_ months: Int, day: Int = 1) -> Date {
            let month = calendar.date(byAdding: .month, value: -months, to: monthStart)!
            return calendar.date(byAdding: .day, value: day - 1, to: month)!
        }
        // Recurring charges
        let charges: [(String, Double, ChargeCategory, Int, String)] = [
            ("Rent", 850, .housing, 5, ""),
            ("Electricity", 64, .utilities, 8, "⚡️"),
            ("Internet", 29.99, .utilities, 10, "📶"),
            ("Car insurance", 48.50, .insurance, 12, ""),
            ("Netflix", 13.49, .subscriptions, 15, ""),
            ("Yoga", 35, .health, 1, "🧘‍♀️"),
        ]
        for (title, amount, category, day, emoji) in charges {
            context.insert(FixedCharge(title: title, amount: amount, category: category, dayOfMonth: day, emoji: emoji))
        }

        // Investments: monthly buys and snapshots over a year
        let etf = Investment(name: "MSCI World", ticker: "CW8", kind: .etf)
        let crypto = Investment(name: "Bitcoin", ticker: "BTC", kind: .crypto)
        let savings = Investment(name: "Savings account", kind: .savings)
        let gold = Investment(name: "Gold coins", ticker: "XAU", kind: .metal)
        for investment in [etf, crypto, savings, gold] { context.insert(investment) }

        for i in 0..<12 {
            let monthsBack = 11 - i
            let etfPrice = 420 + Double(i) * 6 + (i.isMultiple(of: 3) ? -9 : 4)
            add(Trade(date: monthsAgo(monthsBack, day: 3), quantity: 2, unitPrice: etfPrice, fees: 1.5), to: etf, context)
            add(PriceSnapshot(date: monthsAgo(monthsBack, day: 20), unitPrice: etfPrice + 5), to: etf, context)

            let btcPrice = 52_000 + Double(i) * 2_600 + (i.isMultiple(of: 2) ? 4_000 : -3_500)
            add(PriceSnapshot(date: monthsAgo(monthsBack, day: 20), unitPrice: btcPrice), to: crypto, context)
        }
        add(Trade(date: monthsAgo(11, day: 5), quantity: 0.05, unitPrice: 50_000, fees: 10), to: crypto, context)
        add(Trade(date: monthsAgo(5, day: 5), quantity: 0.03, unitPrice: 61_000, fees: 8), to: crypto, context)

        add(Trade(date: monthsAgo(11, day: 1), quantity: 5_000, unitPrice: 1), to: savings, context)

        add(Trade(date: monthsAgo(10, day: 12), quantity: 4, unitPrice: 395, fees: 12), to: gold, context)
        for (monthsBack, price) in [(8, 410.0), (5, 446.0), (2, 492.0), (0, 515.0)] {
            add(PriceSnapshot(date: monthsAgo(monthsBack, day: 1), unitPrice: price), to: gold, context)
        }
        add(PriceSnapshot(date: monthsAgo(5, day: 30), unitPrice: 1.015), to: savings, context)
        add(PriceSnapshot(date: monthsAgo(0, day: 1), unitPrice: 1.03), to: savings, context)
    }

    private static func add(_ trade: Trade, to investment: Investment, _ context: ModelContext) {
        context.insert(trade)
        investment.trades.append(trade)
    }

    private static func add(_ snapshot: PriceSnapshot, to investment: Investment, _ context: ModelContext) {
        context.insert(snapshot)
        investment.snapshots.append(snapshot)
    }
}

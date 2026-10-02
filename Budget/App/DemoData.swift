import Foundation
import SwiftData

/// Sample data used by the UI tests (launch argument `-demo-data`).
/// Stored in memory only: it never touches the user's real data.
enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-data")
    }

    /// Settings that tests expect at their default value. Not passed as
    /// launch arguments: those would override what the app saves during the test.
    static let resetKeys = ["includeHome", "netWorthHigh", "investmentsHigh"]

    static func makeContainer(for schema: Schema) -> ModelContainer {
        for key in resetKeys { UserDefaults.standard.removeObject(forKey: key) }
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

        // Investments: a snapshot every month over a year
        let etf = Investment(name: "MSCI World", ticker: "CW8", kind: .etf)
        let crypto = Investment(name: "Bitcoin", ticker: "BTC", kind: .crypto)
        let savings = Investment(name: "Savings account", kind: .savings)
        let gold = Investment(name: "Gold coins", ticker: "XAU", kind: .metal)
        for investment in [etf, crypto, savings, gold] { context.insert(investment) }

        // Savings plan: 200 € to the savings account and 300 € to gold every month
        savings.monthlyContribution = 200
        gold.monthlyContribution = 300

        var goldCoins = 4.0
        for i in 0..<12 {
            let date = min(monthsAgo(11 - i, day: 20), now)
            let step = Double(i)

            let shares = 10 + step
            let etfPrice = 420 + step * 6 + (i.isMultiple(of: 3) ? -9 : 4)
            add(ValueSnapshot(date: date, value: shares * etfPrice, invested: shares * 418,
                              quantity: shares, unitPrice: etfPrice), to: etf, context)

            let btcPrice = 52_000 + step * 2_600 + (i.isMultiple(of: 2) ? 4_000 : -3_500)
            let coins = i < 6 ? 0.05 : 0.08
            add(ValueSnapshot(date: date, value: coins * btcPrice, invested: i < 6 ? 2_510 : 4_348,
                              quantity: coins, unitPrice: btcPrice), to: crypto, context)

            let saved = 5_000 + 200 * step
            add(ValueSnapshot(date: date, value: saved * (1 + 0.0025 * step), invested: saved), to: savings, context)

            if i >= 1 {
                // Gold dips some months: savings still count, only the value moves
                let goldPrice = 395 + step * 11 + (i.isMultiple(of: 4) ? -30 : 0)
                if i >= 2 { goldCoins += 300 / goldPrice }
                add(ValueSnapshot(date: date, value: goldCoins * goldPrice, invested: 1_592 + 300 * Double(i - 1),
                                  quantity: goldCoins, unitPrice: goldPrice), to: gold, context)
            }
        }

        // Home loan: a snapshot every 6 months over 4 years
        let home = Loan(name: "Apartment", borrowed: 240_000)
        context.insert(home)
        for half in 0...8 {
            let date = min(monthsAgo(48 - half * 6, day: 10), now)
            let remaining = 240_000 - Double(half) * 12_400 - Double(half * half) * 90
            let homeValue = 265_000 + Double(half) * 2_500
            let snapshot = LoanSnapshot(date: date, remaining: remaining, homeValue: homeValue)
            context.insert(snapshot)
            home.history.append(snapshot)
        }
    }

    private static func add(_ snapshot: ValueSnapshot, to investment: Investment, _ context: ModelContext) {
        context.insert(snapshot)
        investment.history.append(snapshot)
    }
}

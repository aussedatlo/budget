import Foundation
import SwiftData
import SwiftUI

/// Sample data used by the UI tests (launch argument `-demo-data`).
/// Stored in memory only: it never touches the user's real data.
enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-data")
    }

    /// Months skipped before the current one (`-demo-missed-months 2`), to test
    /// catching up: their snapshots and the current month's are left out.
    static var missedMonths: Int {
        UserDefaults.standard.integer(forKey: "demo-missed-months")
    }

    /// Settings that tests expect at their default value. Not passed as
    /// launch arguments: those would override what the app saves during the test.
    static let resetKeys = ["includeHome", "netWorthHigh", "investmentsHigh", "hiddenInvestments"]

    static func makeContainer(for schema: Schema) -> ModelContainer {
        for key in resetKeys { UserDefaults.standard.removeObject(forKey: key) }
        // A name of its own, so a store made to start over shares nothing with the one before
        let configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        seed(context)
        try? context.save()
        return container
    }

    // MARK: - Starting over

    /// Sent between processes by the UI tests to get the demo data back as at
    /// launch, which is much faster than launching the app again for every test.
    static let resetSignal = "com.aussedatlo.budget.demo-reset"
    static let resetRequested = Notification.Name("demo-reset-requested")

    /// Stores replaced when starting over. A sheet still sliding away keeps
    /// showing their models, and reading a model whose store is gone crashes
    /// the app, so they are kept until the app quits.
    private static var retired: [ModelContainer] = []

    static func retire(_ container: ModelContainer) {
        retired.append(container)
    }

    /// Passes the tests' signal on inside the app. Debug builds only.
    static func listenForResets() {
        #if DEBUG
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: DemoData.resetRequested, object: nil)
                }
            },
            resetSignal as CFString, nil, .deliverImmediately)
        #endif
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

        // Income: a salary, freelance work this month, no tutoring
        let salary = IncomeSource(title: "Salary", amount: 2_500, emoji: "🏢")
        salary.createdAt = .distantPast
        context.insert(salary)
        context.insert(IncomeSource(title: "Freelance", amount: 400, emoji: "💼"))
        context.insert(IncomeSource(title: "Tutoring", amount: 150, emoji: "🎓", isActive: false))

        // Money lent: Lucas pays back 250 € a month, Emma when she can
        let lucas = Lending(name: "Lucas", emoji: "🚗", lent: 3_000, date: monthsAgo(7, day: 3), monthlyRepayment: 250)
        let emma = Lending(name: "Emma", emoji: "🎓", lent: 600, date: monthsAgo(2, day: 12))
        context.insert(lucas)
        context.insert(emma)
        // What's left, recorded from time to time
        for (months, remaining) in [(5, 2_500.0), (3, 2_000.0), (1, 1_500.0)] {
            let snapshot = LendingSnapshot(date: monthsAgo(months, day: 5), remaining: remaining)
            context.insert(snapshot)
            lucas.history.append(snapshot)
        }
        let fromEmma = LendingSnapshot(date: monthsAgo(1, day: 20), remaining: 400, note: "Paid back 200 in cash")
        context.insert(fromEmma)
        emma.history.append(fromEmma)

        // Investments: a snapshot of everything every month over a year
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

            if missedMonths > 0 && i >= 11 - missedMonths { continue }
            // The monthly budget that month: a raise, a rent increase, new subscriptions
            let snapshot = Snapshot(date: date)
            let salary = i < 5 ? 2_350.0 : 2_500
            let freelance = i.isMultiple(of: 3) ? 400.0 : 0
            snapshot.otherIncome = salary + freelance
            snapshot.repayments = i >= 5 ? 250 : 0
            snapshot.savings = i >= 1 ? 500 : 200
            let past = charges.filter { charge in
                (charge.0 != "Netflix" || i >= 3) && (charge.0 != "Yoga" || i >= 7)
            }
            snapshot.chargeLines = past.map { charge in
                SnapshotLine(title: charge.0, amount: charge.0 == "Rent" && i < 6 ? 820 : charge.1,
                             category: charge.2.rawValue)
            }
            snapshot.charges = snapshot.chargeLines.reduce(0) { $0 + $1.amount }
            var incomeLines = [SnapshotLine(title: "Salary", amount: salary)]
            if freelance > 0 {
                incomeLines.append(SnapshotLine(title: "Freelance", amount: freelance))
            }
            if snapshot.repayments > 0 {
                incomeLines.append(SnapshotLine(title: "Repaid by Lucas", amount: snapshot.repayments))
            }
            snapshot.incomeLines = incomeLines
            context.insert(snapshot)
        }

        // Home loan: values recorded every 6 months over 4 years
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

extension View {
    /// With the demo data, runs `reset` when the UI tests ask to start over, and
    /// tells them how many times it did: they wait for `count` to go up.
    @ViewBuilder
    func demoResets(_ count: Int, perform reset: @escaping () -> Void) -> some View {
        #if DEBUG
        if DemoData.isEnabled {
            onReceive(NotificationCenter.default.publisher(for: DemoData.resetRequested)) { _ in reset() }
                .overlay(alignment: .topLeading) {
                    // Invisible, read by the tests
                    Text("\(count)")
                        .font(.system(size: 1))
                        .foregroundStyle(.clear)
                        .accessibilityIdentifier("demo-resets")
                        .allowsHitTesting(false)
                }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

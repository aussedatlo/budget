import BudgetCore
import SwiftUI

@main
struct BudgetApp: App {
    @State private var model: BudgetModel
    /// How many times the UI tests asked to start over (see `demoResets`).
    @State private var demoResets = 0

    init() {
        let repository: BudgetRepository
        if DemoData.isEnabled {
            repository = DemoData.makeRepository()
            DemoData.listenForResets()
        } else {
            repository = BudgetStore.shared.open(factory: DatabaseFactory())
            LegacyStore.importIfNeeded(into: repository)
            Self.moveMainIncome(to: repository)
        }
        _model = State(initialValue: BudgetModel(repository: repository))
    }

    /// The main income used to be a setting of its own: it becomes an
    /// income line, listed first, and the setting is removed.
    private static func moveMainIncome(to repository: BudgetRepository) {
        let defaults = UserDefaults.standard
        let amount = defaults.double(forKey: AppSettings.legacyIncomeKey)
        guard amount > 0 else { return }
        BudgetModel(repository: repository).addLegacySalary(amount: amount)
        defaults.removeObject(forKey: AppSettings.legacyIncomeKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                // A new id rebuilds every screen: tab, sheets and scroll positions
                .id(demoResets)
                .demoResets(demoResets) {
                    model.replace(with: DemoData.makeRepository())
                    demoResets += 1
                }
        }
    }
}

struct ContentView: View {
    enum Tab: String, Hashable { case monthly, income, investments, stats }

    @State private var selection: Tab = DemoData.startTab.flatMap { Tab(rawValue: $0) } ?? .monthly
    @State private var showingSettings = false
    @State private var showingSnapshot = false
    // Re-render everything when the display currency changes.
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    var body: some View {
        TabView(selection: $selection) {
            MonthlyView(showingSettings: $showingSettings, showingSnapshot: $showingSnapshot, tab: $selection)
                .tabItem { Label("Budget", systemImage: "wallet.pass") }
                .tag(Tab.monthly)
            IncomeView(showingSnapshot: $showingSnapshot)
                .tabItem { Label("Income", systemImage: "banknote") }
                .tag(Tab.income)
            InvestmentsView(showingSnapshot: $showingSnapshot)
                .tabItem { Label("Wealth", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.investments)
            StatsView(showingSnapshot: $showingSnapshot)
                .tabItem { Label("Trends", systemImage: "chart.bar.xaxis") }
                .tag(Tab.stats)
        }
        .id(currency)
        .tint(Theme.accent)
        // Outside the .id() so changing the currency doesn't close it
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingSnapshot) { SnapshotView() }
    }
}

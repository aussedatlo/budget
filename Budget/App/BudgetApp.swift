import SwiftData
import SwiftUI

@main
struct BudgetApp: App {
    private static let schema = Schema([
        Investment.self,
        ValueSnapshot.self,
        Loan.self,
        LoanSnapshot.self,
        FixedCharge.self,
        IncomeSource.self,
        Lending.self,
        LendingSnapshot.self,
        Snapshot.self,
    ])

    @State private var container: ModelContainer
    /// How many times the UI tests asked to start over (see `demoResets`).
    @State private var demoResets = 0

    init() {
        let container: ModelContainer
        if DemoData.isEnabled {
            container = DemoData.makeContainer(for: Self.schema)
            DemoData.listenForResets()
        } else {
            container = Self.makeContainer(for: Self.schema)
            Self.moveMainIncome(to: container)
        }
        _container = State(initialValue: container)
    }

    /// The main income used to be a setting of its own: it becomes an
    /// income line, listed first, and the setting is removed.
    private static func moveMainIncome(to container: ModelContainer) {
        let defaults = UserDefaults.standard
        let amount = defaults.double(forKey: AppSettings.legacyIncomeKey)
        guard amount > 0 else { return }
        let context = ModelContext(container)
        let salary = IncomeSource(title: "Salary", amount: amount)
        salary.createdAt = .distantPast
        context.insert(salary)
        if (try? context.save()) != nil {
            defaults.removeObject(forKey: AppSettings.legacyIncomeKey)
        }
    }

    /// Opens the store. Data from an early test version that can't be
    /// migrated is discarded rather than crashing at launch.
    private static func makeContainer(for schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema)
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            return container
        }
        let url = configuration.url
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
        return try! ModelContainer(for: schema, configurations: configuration)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                // A new id rebuilds every screen: tab, sheets and scroll positions
                .id(demoResets)
                .demoResets(demoResets) {
                    DemoData.retire(container)
                    container = DemoData.makeContainer(for: Self.schema)
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

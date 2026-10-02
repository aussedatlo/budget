import SwiftData
import SwiftUI

@main
struct BudgetApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Investment.self,
            Trade.self,
            PriceSnapshot.self,
            Expense.self,
            FixedCharge.self,
        ])
        if DemoData.isEnabled {
            container = DemoData.makeContainer(for: schema)
        } else {
            container = try! ModelContainer(for: schema)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

struct ContentView: View {
    enum Tab: Hashable { case expenses, investments, settings }

    @State private var selection: Tab = .expenses
    // Re-render everything when the display currency changes.
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    var body: some View {
        TabView(selection: $selection) {
            ExpensesView()
                .tabItem { Label("Expenses", systemImage: "creditcard") }
                .tag(Tab.expenses)
            InvestmentsView()
                .tabItem { Label("Investments", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.investments)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .id(currency)
    }
}

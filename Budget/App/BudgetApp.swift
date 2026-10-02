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
    enum Tab: Hashable { case monthly, investments }

    @State private var selection: Tab = .monthly
    @State private var showingSettings = false
    // Re-render everything when the display currency changes.
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    var body: some View {
        TabView(selection: $selection) {
            MonthlyView(showingSettings: $showingSettings)
                .tabItem { Label("Monthly", systemImage: "calendar") }
                .tag(Tab.monthly)
            InvestmentsView()
                .tabItem { Label("Investments", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.investments)
        }
        .id(currency)
        // Outside the .id() so changing the currency doesn't close it
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }
}

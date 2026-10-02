import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @AppStorage(AppSettings.budgetKey) private var budget: Double = 0

    private var currencies: [String] {
        Array(Set(["EUR", "USD", "GBP", "CHF", "CAD", "JPY", "AUD", currency])).sorted()
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Monthly budget") {
                        TextField("0", value: $budget, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Expenses")
                } footer: {
                    Text("Fixed charges and expenses are compared to this amount every month. 0 disables it.")
                }
                Section("Display") {
                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section {
                    LabeledContent("Version", value: version)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
        }
    }
}

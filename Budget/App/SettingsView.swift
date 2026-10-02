import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

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
                    HStack(spacing: 12) {
                        Moji("🫙", size: 44)
                        Moji("💖", size: 44)
                        Moji("🌸", size: 44)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Picker("Currency", selection: $currency) {
                    ForEach(currencies, id: \.self) { Text($0).tag($0) }
                }
                LabeledContent("Version", value: version)
                Section {
                    Link(destination: OpenMoji.url) {
                        Text(OpenMoji.credit)
                            .font(.footnote)
                            .foregroundStyle(Theme.softInk)
                    }
                }
            }
            .themedForm()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

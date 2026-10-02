import SwiftUI

enum AppSettings {
    static let currencyKey = "currencyCode"
    static let budgetKey = "monthlyBudget"

    static var defaultCurrency: String { Locale.current.currency?.identifier ?? "EUR" }

    static var currencyCode: String {
        UserDefaults.standard.string(forKey: currencyKey) ?? defaultCurrency
    }
}

extension Double {
    var currency: String {
        formatted(.currency(code: AppSettings.currencyCode))
    }

    var signedCurrency: String {
        formatted(.currency(code: AppSettings.currencyCode).sign(strategy: .always()))
    }

    var signedPercent: String {
        formatted(.percent.precision(.fractionLength(2)).sign(strategy: .always()))
    }

    var quantityText: String {
        formatted(.number.precision(.fractionLength(0...6)))
    }
}

extension Color {
    static func gain(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}

extension Calendar {
    func monthInterval(for date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }
}

/// A small label / value block used in summary cards.
struct StatTile: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

import SwiftUI

enum AppSettings {
    static let currencyKey = "currencyCode"
    static let incomeKey = "monthlyIncome"

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

extension Calendar {
    func monthInterval(for date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }
}

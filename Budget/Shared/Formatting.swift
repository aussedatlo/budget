import SwiftUI

enum AppSettings {
    static let currencyKey = "currencyCode"
    /// Main income of earlier versions, moved to an income line at launch.
    static let legacyIncomeKey = "monthlyIncome"

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

    /// Short form for chart axes, e.g. "12K".
    var compact: String {
        formatted(.number.notation(.compactName))
    }

    var quantityText: String {
        formatted(.number.precision(.fractionLength(0...6)))
    }
}

extension Date {
    /// "October 2026"
    var monthName: String {
        formatted(.dateTime.month(.wide).year())
    }
}

extension Calendar {
    func monthInterval(for date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }

    /// The last second of the day `date` is in.
    func endOfDay(for date: Date) -> Date {
        self.date(byAdding: .day, value: 1, to: startOfDay(for: date))!.addingTimeInterval(-1)
    }

    /// The last second of the month `date` is in.
    func endOfMonth(for date: Date) -> Date {
        monthInterval(for: date).end.addingTimeInterval(-1)
    }

    func isDate(_ date: Date, inSameMonthAs other: Date) -> Bool {
        isDate(date, equalTo: other, toGranularity: .month)
    }

    /// Number of calendar months from `start` to `end` (0 within the same month).
    func monthsBetween(_ start: Date, _ end: Date) -> Int {
        let from = dateComponents([.year, .month], from: start)
        let to = dateComponents([.year, .month], from: end)
        let months = ((to.year ?? 0) - (from.year ?? 0)) * 12 + (to.month ?? 0) - (from.month ?? 0)
        return max(months, 0)
    }
}

import Foundation
import SwiftData
import SwiftUI

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case housing, food, transport, utilities, health, leisure, shopping, subscriptions, travel, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .housing: "Housing"
        case .food: "Food"
        case .transport: "Transport"
        case .utilities: "Utilities"
        case .health: "Health"
        case .leisure: "Leisure"
        case .shopping: "Shopping"
        case .subscriptions: "Subscriptions"
        case .travel: "Travel"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .housing: "house.fill"
        case .food: "cart.fill"
        case .transport: "car.fill"
        case .utilities: "bolt.fill"
        case .health: "cross.case.fill"
        case .leisure: "gamecontroller.fill"
        case .shopping: "bag.fill"
        case .subscriptions: "repeat"
        case .travel: "airplane"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .housing: .indigo
        case .food: .green
        case .transport: .blue
        case .utilities: .yellow
        case .health: .red
        case .leisure: .purple
        case .shopping: .pink
        case .subscriptions: .orange
        case .travel: .teal
        case .other: .gray
        }
    }
}

/// A one-off expense.
@Model
final class Expense {
    var title: String = ""
    var amount: Double = 0
    var date: Date = Date.now
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var note: String = ""

    init(title: String, amount: Double, date: Date = .now,
         category: ExpenseCategory = .other, note: String = "") {
        self.title = title
        self.amount = amount
        self.date = date
        self.categoryRaw = category.rawValue
        self.note = note
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

/// A charge that repeats every month (rent, subscriptions...).
@Model
final class FixedCharge {
    var title: String = ""
    var amount: Double = 0
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var dayOfMonth: Int = 1
    var startDate: Date = Date.now
    /// Set when the charge is stopped; it keeps counting in earlier months.
    var endDate: Date?

    init(title: String, amount: Double, category: ExpenseCategory = .other,
         dayOfMonth: Int = 1, startDate: Date = .now) {
        self.title = title
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.dayOfMonth = dayOfMonth
        self.startDate = startDate
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var isActive: Bool { endDate == nil }

    func applies(to month: DateInterval) -> Bool {
        let started = Calendar.current.monthInterval(for: startDate).start < month.end
        let notEnded = endDate.map { $0 >= month.start } ?? true
        return started && notEnded
    }
}

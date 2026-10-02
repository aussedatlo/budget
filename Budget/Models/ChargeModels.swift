import Foundation
import SwiftData
import SwiftUI

enum ChargeCategory: String, CaseIterable, Identifiable {
    case housing, utilities, insurance, subscriptions, transport, health, loans, leisure, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .housing: "Housing"
        case .utilities: "Utilities"
        case .insurance: "Insurance"
        case .subscriptions: "Subscriptions"
        case .transport: "Transport"
        case .health: "Health"
        case .loans: "Loans"
        case .leisure: "Leisure"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .housing: "house.fill"
        case .utilities: "bolt.fill"
        case .insurance: "shield.fill"
        case .subscriptions: "repeat"
        case .transport: "car.fill"
        case .health: "cross.case.fill"
        case .loans: "building.columns.fill"
        case .leisure: "gamecontroller.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .housing: .indigo
        case .utilities: .yellow
        case .insurance: .teal
        case .subscriptions: .orange
        case .transport: .blue
        case .health: .red
        case .loans: .brown
        case .leisure: .purple
        case .other: .gray
        }
    }
}

/// A charge paid every month (rent, subscriptions, insurance...).
@Model
final class FixedCharge {
    var title: String = ""
    var amount: Double = 0
    var categoryRaw: String = ChargeCategory.other.rawValue
    var dayOfMonth: Int = 1

    init(title: String, amount: Double, category: ChargeCategory = .other, dayOfMonth: Int = 1) {
        self.title = title
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.dayOfMonth = dayOfMonth
    }

    var category: ChargeCategory {
        get { ChargeCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

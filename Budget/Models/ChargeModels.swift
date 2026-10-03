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

    var emoji: String {
        switch self {
        case .housing: "🏠"
        case .utilities: "💡"
        case .insurance: "🛡️"
        case .subscriptions: "📺"
        case .transport: "🚗"
        case .health: "💊"
        case .loans: "🏦"
        case .leisure: "🎮"
        case .other: "🌸"
        }
    }

    /// Pastel background for the emoji bubble.
    var color: Color {
        switch self {
        case .housing: Theme.peach
        case .utilities: Theme.butter
        case .insurance: Theme.sky
        case .subscriptions: Theme.lavender
        case .transport: Theme.sky
        case .health: Theme.pink
        case .loans: Theme.butter
        case .leisure: Theme.mint
        case .other: Theme.pink
        }
    }
}

/// A charge paid every month (rent, subscriptions, insurance...).
@Model
final class FixedCharge {
    var title: String = ""
    var amount: Double = 0
    var categoryRaw: String = ChargeCategory.other.rawValue
    /// No longer shown or edited; kept so stored data opens unchanged.
    var dayOfMonth: Int = 1
    var emoji: String = ""

    init(title: String, amount: Double, category: ChargeCategory = .other,
         dayOfMonth: Int = 1, emoji: String = "") {
        self.title = title
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.dayOfMonth = dayOfMonth
        self.emoji = emoji
    }

    var displayEmoji: String { emoji.isEmpty ? category.emoji : emoji }

    var category: ChargeCategory {
        get { ChargeCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

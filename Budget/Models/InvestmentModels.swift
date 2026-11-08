import Foundation
import SwiftUI

enum InvestmentKind: String, CaseIterable, Identifiable {
    case stock = "Stock"
    case etf = "ETF"
    case fund = "Fund"
    case crypto = "Crypto"
    case metal = "Precious metal"
    case savings = "Savings"
    case realEstate = "Real estate"
    case other = "Other"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .stock: "📈"
        case .etf: "🌍"
        case .fund: "💼"
        case .crypto: "🪙"
        case .metal: "🥇"
        case .savings: "🐷"
        case .realEstate: "🏠"
        case .other: "💎"
        }
    }

    var color: Color {
        switch self {
        case .stock: Theme.sky
        case .etf: Theme.mint
        case .fund: Theme.lavender
        case .crypto: Theme.peach
        case .metal: Theme.butter
        case .savings: Theme.pink
        case .realEstate: Theme.peach
        case .other: Theme.lavender
        }
    }

    /// Its part of the Wealth bar: stronger than `color`, apart from the
    /// home's rose and money lent's blue.
    var barColor: Color {
        switch self {
        case .stock: Theme.series[4]
        case .etf: Theme.series[2]
        case .fund: Theme.series[5]
        case .crypto: Color(light: 0xD08A4E, dark: 0xE8A673)
        case .metal: Theme.series[3]
        case .savings: Color(light: 0xD9A0AE, dark: 0xE8B7C3)
        case .realEstate: Color(light: 0xA67B5B, dark: 0xC79B7B)
        case .other: Color(light: 0x9A97A3, dark: 0xB5B2BE)
        }
    }
}

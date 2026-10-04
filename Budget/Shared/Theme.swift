import SwiftUI
import UIKit

/// Calm palette: neutral background, white cards, one dusty-rose accent
/// and very light tints for icon bubbles.
enum Theme {
    static let background = Color(light: 0xF6F5F2, dark: 0x141316)
    static let card = Color(light: 0xFFFFFF, dark: 0x1F1E22)
    static let ink = Color(light: 0x2A2830, dark: 0xF2F1F4)
    static let softInk = Color(light: 0x85828E, dark: 0x9D9AA6)
    static let accent = Color(light: 0xC0687A, dark: 0xE0909E)

    // Light tints behind icons
    static let pink = Color(light: 0xF7EBEE, dark: 0x2E2428)
    static let peach = Color(light: 0xF6EEE7, dark: 0x2E2924)
    static let mint = Color(light: 0xEAF2ED, dark: 0x222B26)
    static let lavender = Color(light: 0xEEEDF5, dark: 0x26252E)
    static let butter = Color(light: 0xF6F2E4, dark: 0x2C2A21)
    static let sky = Color(light: 0xEAF0F6, dark: 0x222830)

    /// Distinct, muted colors for chart series.
    static let series: [Color] = [
        accent,
        Color(light: 0x6B8CB8, dark: 0x8FAEDA),
        Color(light: 0x7FA588, dark: 0x9CC5A6),
        Color(light: 0xC4A064, dark: 0xDDBB82),
        Color(light: 0x9585BF, dark: 0xB3A5DC),
        Color(light: 0x5E9EA0, dark: 0x82C0C2),
    ]

    /// What's left of the month, in the income bar.
    static let left = series[2]

    /// Money lent to others: a calm blue, apart from the home loan's rose.
    static let lent = Color(light: 0x6B8CB8, dark: 0x8FAEDA)

    static let positive = Color(light: 0x3B8A66, dark: 0x7CC5A1)
    static let negative = Color(light: 0xBF4E63, dark: 0xF08A9C)

    static func gain(_ value: Double) -> Color {
        if value > 0 { return positive }
        if value < 0 { return negative }
        return softInk
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Building blocks

extension View {
    /// A soft rounded card.
    func card(padding: CGFloat = 16) -> some View {
        card(Theme.card, padding: padding)
    }

    /// A soft rounded card with a custom fill (color or gradient).
    func card<S: ShapeStyle>(_ fill: S, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    /// Neutral background behind forms presented as sheets.
    func themedForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .tint(Theme.accent)
    }
}

/// An emoji sitting in a pastel circle.
struct EmojiBubble: View {
    let emoji: String
    var color: Color = Theme.pink
    var size: CGFloat = 44

    var body: some View {
        Moji(emoji, size: size * 0.66)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }
}

/// Section title with an optional trailing value.
struct SectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).monospacedDigit().foregroundStyle(Theme.softInk)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }
}

/// Capsule button that shrinks slightly when pressed.
struct PillButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

/// Makes cards shrink slightly when tapped.
struct SquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

/// A small label / value block used in summary cards.
struct StatTile: View {
    let title: String
    let value: String
    var color: Color = Theme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.softInk)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A rounded "chip" for small values like a gain percentage.
struct Chip: View {
    let text: String
    var emoji: String?
    var color: Color = Theme.ink
    var background: Color = Theme.background

    var body: some View {
        HStack(spacing: 4) {
            if let emoji { Moji(emoji, size: 15) }
            Text(text)
        }
            .font(.caption.bold())
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .contentTransition(.numericText())
    }
}

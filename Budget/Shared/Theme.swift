import SwiftUI
import UIKit

/// Soft pastel palette, with a cosy dark variant.
enum Theme {
    static let background = Color(light: 0xFFF7F0, dark: 0x1F1A24)
    static let card = Color(light: 0xFFFFFF, dark: 0x2B2433)
    static let ink = Color(light: 0x4B3F58, dark: 0xF4ECF8)
    static let softInk = Color(light: 0x9A8AA8, dark: 0xB5A6C4)
    static let accent = Color(light: 0xF27BA5, dark: 0xF58CB3)

    static let pink = Color(light: 0xFFD6E5, dark: 0x5A3447)
    static let peach = Color(light: 0xFFDCCB, dark: 0x5C3E33)
    static let mint = Color(light: 0xCDEFE0, dark: 0x2F4F43)
    static let lavender = Color(light: 0xE4D8F5, dark: 0x45395C)
    static let butter = Color(light: 0xFFF0C2, dark: 0x564A2A)
    static let sky = Color(light: 0xD3E8FF, dark: 0x2F4560)

    static let positive = Color(light: 0x2F9E74, dark: 0x7FD8B0)
    static let negative = Color(light: 0xE0607E, dark: 0xFF8FA8)

    static func gain(_ value: Double) -> Color {
        if value > 0 { return positive }
        if value < 0 { return negative }
        return softInk
    }

    /// Rounded fonts and colors for the UIKit navigation bars.
    static func configureAppearance() {
        func rounded(_ font: UIFont) -> UIFont {
            font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: font.pointSize) } ?? font
        }
        let ink = UIColor(Theme.ink)
        let large = rounded(.systemFont(ofSize: 34, weight: .bold))
        let small = rounded(.systemFont(ofSize: 17, weight: .semibold))

        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.largeTitleTextAttributes = [.font: large, .foregroundColor: ink]
        scrolled.titleTextAttributes = [.font: small, .foregroundColor: ink]

        let atTop = UINavigationBarAppearance()
        atTop.configureWithTransparentBackground()
        atTop.largeTitleTextAttributes = scrolled.largeTitleTextAttributes
        atTop.titleTextAttributes = scrolled.titleTextAttributes

        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = atTop
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
            .background(fill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.10), radius: 14, y: 6)
    }

    /// Cream background behind forms presented as sheets.
    func themedForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .fontDesign(.rounded)
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
            Text(title).font(.title3.bold())
            Spacer()
            if let trailing {
                Text(trailing).font(.headline).monospacedDigit().foregroundStyle(Theme.softInk)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }
}

/// Capsule button with a little bounce when pressed.
struct PillButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.bouncy, value: configuration.isPressed)
    }
}

/// Makes cards shrink slightly when tapped.
struct SquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.bouncy, value: configuration.isPressed)
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
    var background: Color = Theme.card.opacity(0.7)

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

import SwiftUI
import UIKit

/// Emoji drawn with OpenMoji (https://openmoji.org, CC BY-SA 4.0).
/// The SVGs live in Assets.xcassets/OpenMoji, named by code points
/// without variation selectors, e.g. "🏠" -> "OpenMoji/1F3E0".
enum OpenMoji {
    static func assetName(for emoji: String) -> String {
        let hex = emoji.unicodeScalars
            .filter { $0.value != 0xFE0F }
            .map { String($0.value, radix: 16, uppercase: true) }
            .joined(separator: "-")
        return "OpenMoji/\(hex)"
    }

    /// nil when the emoji isn't bundled.
    static func image(for emoji: String) -> Image? {
        let name = assetName(for: emoji)
        return UIImage(named: name) == nil ? nil : Image(name)
    }

    static let credit = "Icons by OpenMoji, the open-source emoji and icon project. License: CC BY-SA 4.0"
    static let url = URL(string: "https://openmoji.org")!
}

/// An emoji drawn with OpenMoji, or the system emoji when not bundled.
struct Moji: View {
    let emoji: String
    var size: CGFloat = 24

    init(_ emoji: String, size: CGFloat = 24) {
        self.emoji = emoji
        self.size = size
    }

    var body: some View {
        Group {
            if let image = OpenMoji.image(for: emoji) {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Text(emoji)
                    .font(.system(size: size * 0.8))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A line of text followed by an emoji.
struct TextWithMoji: View {
    let text: String
    let emoji: String
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            Moji(emoji, size: size)
        }
    }
}

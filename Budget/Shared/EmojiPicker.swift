import SwiftUI

/// A grid of OpenMoji icons to choose from. Only bundled icons are offered,
/// so everything keeps the same drawing style.
struct EmojiPicker: View {
    @Binding var emoji: String
    let suggestions: [String]

    static let charges = [
        "🏠", "🏡", "🛋️", "💡", "⚡️", "💧", "🔥", "📶",
        "📱", "🌐", "📺", "🎬", "🎵", "🎮", "☁️", "📚",
        "🚗", "⛽️", "🚌", "🚆", "🚲", "✈️", "🛡️", "🏥",
        "💊", "🦷", "🏋️‍♀️", "🧘‍♀️", "💇", "👗", "🛒", "🧺",
        "🐶", "🐱", "🐾", "👶", "🧸", "🎓", "🎨", "🎁",
        "🏦", "💳", "🧾", "🍵", "🍰", "🌸", "🌻", "✨",
    ]

    static let investments = [
        "🌍", "📈", "💹", "🏦", "🏛️", "🪙", "🥇", "🥈",
        "💎", "💰", "🐷", "🫙", "🧧", "🏠", "🏢", "🌱",
        "🌳", "🔋", "🍎", "🌈", "⭐", "✨",
    ]

    static let homes = ["🏠", "🏡", "🏢", "🏘️", "🏚️", "🏰", "🛖", "🏖️", "🔑", "🛋️"]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(suggestions, id: \.self) { item in
                Button {
                    emoji = item
                } label: {
                    Moji(item, size: 30)
                        .frame(width: 40, height: 40)
                        .background(item == emoji ? Theme.pink : .clear, in: Circle())
                        .scaleEffect(item == emoji ? 1.05 : 1)
                        .animation(.snappy, value: emoji)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

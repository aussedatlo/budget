import SwiftUI

/// A grid of suggested emoji, plus a field to type any other one.
struct EmojiPicker: View {
    @Binding var emoji: String
    let suggestions: [String]

    static let charges = [
        "🏠", "🏡", "💡", "⚡️", "💧", "🔥", "📶", "📱",
        "📺", "🎵", "🎮", "☁️", "🚗", "⛽️", "🚌", "🚲",
        "🛡️", "🏥", "💊", "🦷", "🏋️‍♀️", "🧘‍♀️", "🐶", "🐱",
        "👶", "🎓", "🏦", "💳", "🧾", "🧺", "🌸", "✨",
    ]

    static let investments = [
        "🌍", "📈", "💹", "🏦", "🪙", "🥇", "🥈", "💎",
        "₿", "🏠", "🌱", "🔋", "🍎", "💰", "🐷", "🫙",
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(suggestions, id: \.self) { item in
                    Button {
                        emoji = item
                    } label: {
                        Text(item)
                            .font(.title2)
                            .frame(width: 38, height: 38)
                            .background(item == emoji ? Theme.pink : .clear, in: Circle())
                            .scaleEffect(item == emoji ? 1.15 : 1)
                            .animation(.bouncy, value: emoji)
                    }
                    .buttonStyle(.plain)
                }
            }
            LabeledContent("Or type your own") {
                TextField("✨", text: Binding(
                    get: { emoji },
                    // Keep only the last character typed (an emoji is one Character)
                    set: { newValue in emoji = newValue.last.map { String($0) } ?? "" }
                ))
                .multilineTextAlignment(.trailing)
                .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
}

import SwiftUI

/// The header at the top of Budget, Income and Wealth: the tab's icon, a
/// title, one large amount and a bar showing what that amount is made of.
struct TabHeader<Icon: View, Accessory: View, Caption: View>: View {
    let title: String
    let value: Double
    var valueColor: Color = Theme.ink
    var valueIdentifier = "header-value"
    /// What the amount is made of; nil when there's nothing to show yet.
    let bar: CompositionBar?
    @ViewBuilder let icon: Icon
    /// Next to the title, e.g. the net worth button.
    @ViewBuilder let accessory: Accessory
    /// Under the amount, e.g. the income it comes from.
    @ViewBuilder let caption: Caption

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                icon
                    .frame(width: 100)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(Theme.softInk)
                        Spacer()
                        accessory
                    }
                    Text(value.currency)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: value))
                        .animation(.snappy, value: value)
                        .accessibilityIdentifier(valueIdentifier)
                    caption
                        .font(.footnote)
                        .foregroundStyle(Theme.softInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            if let bar { bar }
        }
        .card()
    }
}

/// One part of a `CompositionBar`.
struct BarPart {
    let label: String
    /// Its width in the bar (nothing below 0 is drawn).
    let amount: Double
    let color: Color
    /// The amount written in the legend when it differs from the bar, e.g.
    /// how much over budget. Parts with nothing in the bar are only listed
    /// in the legend when they have one.
    var shown: Double?
    /// Written in red in the legend.
    var isWarning = false

    var legendAmount: Double { shown ?? amount }
}

/// A bar split into colored parts, with a legend giving each part's amount
/// and share. When the parts go past `total`, the bar fills up and a tick
/// marks where the total ends.
struct CompositionBar: View {
    let parts: [BarPart]
    /// What 100% stands for: the sum of the parts unless given.
    var total: Double?

    private var drawn: [BarPart] { parts.filter { $0.amount > 0 } }
    private var listed: [BarPart] { parts.filter { $0.amount > 0 || $0.shown != nil } }
    private var sum: Double { drawn.reduce(0) { $0 + $1.amount } }
    private var base: Double { total ?? sum }
    /// What the full width of the bar stands for.
    private var scale: Double { max(base, sum, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bar
            FlowLayout(spacing: 14, lineSpacing: 8) {
                ForEach(Array(listed.enumerated()), id: \.offset) { _, part in
                    legendItem(part)
                }
            }
        }
    }

    private var bar: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 2
            let usable = geometry.size.width - spacing * CGFloat(max(drawn.count - 1, 0))
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.background)
                HStack(spacing: spacing) {
                    ForEach(Array(drawn.enumerated()), id: \.offset) { _, part in
                        Rectangle()
                            .fill(part.color)
                            .frame(width: max(usable * part.amount / scale, 0))
                    }
                }
                .clipShape(Capsule())
                // Where the total ends when the parts go past it
                if sum > base + 0.005 && base > 0 {
                    Rectangle()
                        .fill(Theme.ink)
                        .frame(width: 2, height: 22)
                        .offset(x: geometry.size.width * base / scale - 1)
                }
            }
        }
        .frame(height: 14)
        .animation(.snappy, value: drawn.map(\.amount))
        .accessibilityElement()
        .accessibilityLabel("Composition")
        .accessibilityIdentifier("header-bar")
    }

    private func legendItem(_ part: BarPart) -> some View {
        let label = Text(part.label).foregroundStyle(Theme.softInk)
        let amount = Text(amountText(for: part))
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(part.isWarning ? Theme.negative : Theme.ink)
        return HStack(spacing: 6) {
            Circle()
                .fill(part.isWarning ? Theme.negative : part.color)
                .frame(width: 8, height: 8)
            // One text, so a legend named like an income line ("Salary") is
            // never read as that line's own text
            Text("\(label)\n\(amount)")
                .font(.caption)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(part.label) \(amountText(for: part))")
        .accessibilityIdentifier("legend-\(part.label)")
    }

    private func amountText(for part: BarPart) -> String {
        let amount = abs(part.legendAmount)
        guard base > 0 else { return amount.currency }
        let share = (amount / base).formatted(.percent.precision(.fractionLength(0)))
        return "\(amount.currency) · \(share)"
    }
}

/// Lays its views out in rows, starting a new row when one doesn't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = frames(for: subviews, width: proposal.width ?? .infinity)
        let width = frames.map(\.maxX).max() ?? 0
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(for: subviews, width: bounds.width)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    private func frames(for subviews: Subviews, width: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return frames
    }
}

import SwiftUI

/// The month's income as one bar: charges, savings and what's left.
/// When charges and savings go over the income, the bar fills up and a
/// tick marks where the income ends.
struct IncomeBar: View {
    let income: Double
    let charges: Double
    let savings: Double

    private struct Segment: Identifiable {
        let label: String
        let amount: Double
        let color: Color
        var id: String { label }
    }

    private var left: Double { income - charges - savings }
    /// What the full width of the bar stands for.
    private var scale: Double { max(income, charges + savings, 1) }

    private var segments: [Segment] {
        [
            Segment(label: "Charges", amount: charges, color: Theme.accent),
            Segment(label: "Savings", amount: savings, color: Theme.series[1]),
            Segment(label: "Left", amount: max(left, 0), color: Theme.left.opacity(0.35)),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bar
            legend
        }
        .accessibilityElement(children: .combine)
    }

    private var bar: some View {
        GeometryReader { geometry in
            let visible = segments.filter { $0.amount > 0 }
            let spacing: CGFloat = 2
            let usable = geometry.size.width - spacing * CGFloat(max(visible.count - 1, 0))
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.background)
                HStack(spacing: spacing) {
                    ForEach(visible) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: max(usable * segment.amount / scale, 0))
                    }
                }
                .clipShape(Capsule())
                // Where the income ends when we're over budget
                if left < 0 && income > 0 {
                    Rectangle()
                        .fill(Theme.ink)
                        .frame(width: 2, height: 22)
                        .offset(x: geometry.size.width * income / scale - 1)
                }
            }
        }
        .frame(height: 14)
        .animation(.snappy, value: charges)
        .animation(.snappy, value: savings)
        .animation(.snappy, value: income)
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendItems }
            VStack(alignment: .leading, spacing: 6) { legendItems }
        }
    }

    @ViewBuilder
    private var legendItems: some View {
        ForEach(segments.filter { $0.amount > 0 || $0.label == "Left" }) { segment in
            HStack(spacing: 6) {
                Circle()
                    .fill(segment.label == "Left" && left < 0 ? Theme.negative : segment.color)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 0) {
                    Text(segment.label == "Left" && left < 0 ? "Over" : segment.label)
                        .font(.caption)
                        .foregroundStyle(Theme.softInk)
                    Text(amountText(for: segment))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(segment.label == "Left" && left < 0 ? Theme.negative : Theme.ink)
                }
            }
        }
    }

    private func amountText(for segment: Segment) -> String {
        let amount = segment.label == "Left" ? left : segment.amount
        guard income > 0 else { return abs(amount).currency }
        let share = (abs(amount) / income).formatted(.percent.precision(.fractionLength(0)))
        return "\(abs(amount).currency) · \(share)"
    }
}

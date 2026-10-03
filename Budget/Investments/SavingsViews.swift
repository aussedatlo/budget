import Charts
import SwiftData
import SwiftUI

/// Money saved each month (from "invested so far"), stacked per position,
/// with the savings plan as a dashed line.
struct SavingsChart: View {
    let investments: [Investment]

    private var points: [SavingsPoint] { Savings.monthly(for: investments) }
    private var plan: Double { investments.reduce(0) { $0 + $1.monthlyContribution } }

    private var totalsByMonth: [Date: Double] {
        Dictionary(grouping: points, by: \.month).mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    private var average: Double {
        let totals = totalsByMonth
        return totals.isEmpty ? 0 : totals.values.reduce(0, +) / Double(totals.count)
    }

    private var thisMonth: Double {
        totalsByMonth[Calendar.current.monthInterval(for: .now).start] ?? 0
    }

    /// Position names in a stable order, without duplicates.
    private var names: [String] {
        var seen = Set<String>()
        return investments.map(\.name).filter { seen.insert($0).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Saved per month")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if !points.isEmpty {
                    Text("avg \(average.currency)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.softInk)
                }
            }
            if points.isEmpty {
                Text("Keep “invested so far” up to date to see how much you save each month. Market moves don't count, only the money you put in.")
                    .font(.footnote)
                    .foregroundStyle(Theme.softInk)
            } else {
                HStack(spacing: 6) {
                    Chip(text: "This month \(thisMonth.currency)", color: Theme.gain(thisMonth))
                    if plan > 0 {
                        Chip(text: "Plan \(plan.currency)")
                    }
                }
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Month", point.month, unit: .month),
                            y: .value("Saved", point.amount)
                        )
                        .foregroundStyle(by: .value("Position", point.investment))
                        .cornerRadius(3)
                    }
                    if plan > 0 {
                        RuleMark(y: .value("Plan", plan))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Theme.softInk)
                    }
                }
                .chartForegroundStyleScale(
                    domain: names,
                    range: names.indices.map { Theme.series[$0 % Theme.series.count] }
                )
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        AxisValueLabel()
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 190)
            }
        }
        .card()
    }
}

/// Edit how much goes to each position every month.
struct SavingsPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Investment.name) private var investments: [Investment]

    private var total: Double { investments.reduce(0) { $0 + $1.monthlyContribution } }

    var body: some View {
        NavigationStack {
            Form {
                if investments.isEmpty {
                    Text("Add an investment first (Wealth tab), then come back to plan your monthly savings.")
                        .foregroundStyle(Theme.softInk)
                } else {
                    Section {
                        ForEach(investments) { investment in
                            HStack(spacing: 10) {
                                Moji(investment.displayEmoji, size: 22)
                                NumberField(
                                    title: investment.name,
                                    value: Binding(
                                        get: { investment.monthlyContribution > 0 ? investment.monthlyContribution : nil },
                                        set: { investment.monthlyContribution = max($0 ?? 0, 0) }
                                    )
                                )
                            }
                        }
                    } footer: {
                        Text("Set aside on the Budget screen, and added to “invested so far” in your next snapshot. You can always correct a month that was different.")
                    }
                    Section {
                        LabeledContent("Every month", value: total.currency)
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Savings plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

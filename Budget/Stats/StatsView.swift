import Charts
import SwiftData
import SwiftUI

/// How everything moved over time: net worth, investments, the monthly
/// budget and savings, from one snapshot to the next.
struct StatsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Investment.name) private var investments: [Investment]
    @Query(sort: \Loan.name) private var loans: [Loan]
    @Query private var lendings: [Lending]
    @Query(sort: \Snapshot.date) private var snapshots: [Snapshot]
    @Binding var showingSnapshot: Bool
    @State private var selected: SnapshotSummary?
    @State private var deleting: Snapshot?

    private var now: WealthPoint {
        Wealth.point(investments: investments, loans: loans, lendings: lendings)
    }

    /// Newest first, each with the net worth at the end of its month.
    private var summaries: [SnapshotSummary] {
        var previous: Double?
        var result: [SnapshotSummary] = []
        for snapshot in snapshots {
            let wealth = Wealth.point(at: snapshot.endOfMonth,
                                      investments: investments, loans: loans, lendings: lendings)
            result.append(SnapshotSummary(snapshot: snapshot, wealth: wealth,
                                          change: previous.map { wealth.netWorth - $0 }))
            previous = wealth.netWorth
        }
        return result.reversed()
    }

    var body: some View {
        let points = Wealth.points(investments: investments, loans: loans, lendings: lendings)
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header(points: points)
                    ChartCard(title: "Net worth over time") {
                        NetWorthChart(points: points, showsHome: !loans.isEmpty, showsLent: !lendings.isEmpty)
                    }
                    if !investments.isEmpty {
                        ChartCard(title: "Investments") {
                            HistoryChart(points: History.points(for: investments))
                        }
                        SavingsChart(investments: investments)
                    }
                    ChartCard(title: "Monthly budget", trailing: snapshots.last.map { "left \($0.left.currency)" }) {
                        BudgetChart(snapshots: snapshots)
                    }
                    ChartCard(title: "Recurring charges", trailing: snapshots.last.map { $0.charges.currency }) {
                        ChargesChart(snapshots: snapshots)
                    }
                    snapshotList
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .animation(.snappy, value: snapshots.count)
            }
            .background(Theme.background)
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SnapshotButton(isPresented: $showingSnapshot)
                }
            }
            .sheet(item: $selected, onDismiss: deletePending) { summary in
                SnapshotDetailView(summary: summary, showsHome: !loans.isEmpty) {
                    deleting = summary.snapshot
                }
            }
            .sensoryFeedback(.success, trigger: snapshots.count) { old, new in new > old }
        }
    }

    private func header(points: [WealthPoint]) -> some View {
        let netWorth = now.netWorth
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Net worth")
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
                Text(netWorth.currency)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: netWorth))
                    .animation(.snappy, value: netWorth)
            }
            FlowChips {
                if let first = points.first, points.count > 1 {
                    let change = netWorth - first.netWorth
                    Chip(
                        text: "\(change.signedCurrency) since \(first.date.formatted(.dateTime.month(.abbreviated).year()))",
                        color: Theme.gain(change)
                    )
                }
                if let last = snapshots.last {
                    Chip(text: "Last snapshot \(last.date.monthName)")
                }
            }
            Text("Once a month or so, update your charges, income and investments, then take the month's snapshot: it saves the whole picture and adds a point to these charts.")
                .font(.footnote)
                .foregroundStyle(Theme.softInk)
            Button("Take a snapshot", systemImage: "camera") { showingSnapshot = true }
                .buttonStyle(PillButtonStyle())
        }
        .card()
    }

    @ViewBuilder
    private var snapshotList: some View {
        SectionTitle(title: "Snapshots")
        let summaries = self.summaries
        if summaries.isEmpty {
            Text("No snapshot yet. The first one starts the budget charts; the net worth already shows the values you recorded before.")
                .font(.subheadline)
                .foregroundStyle(Theme.softInk)
                .card()
        }
        ForEach(summaries) { summary in
            Button { selected = summary } label: { SnapshotSummaryRow(summary: summary) }
                .buttonStyle(SquishyButtonStyle())
                .transition(.opacity)
        }
    }

    /// Deletes the snapshot picked in the detail sheet, once the sheet is closed,
    /// along with the values recorded that month.
    private func deletePending() {
        guard let snapshot = deleting else { return }
        deleting = nil
        let calendar = Calendar.current
        let day = snapshot.date
        for investment in investments {
            let entries = investment.history.filter { calendar.isDate($0.date, inSameMonthAs: day) }
            investment.history.removeAll { entries.contains($0) }
            entries.forEach { context.delete($0) }
        }
        for loan in loans {
            let entries = loan.history.filter { calendar.isDate($0.date, inSameMonthAs: day) }
            loan.history.removeAll { entries.contains($0) }
            entries.forEach { context.delete($0) }
        }
        for lending in lendings {
            let entries = lending.history.filter { calendar.isDate($0.date, inSameMonthAs: day) }
            lending.history.removeAll { entries.contains($0) }
            entries.forEach { context.delete($0) }
        }
        withAnimation(.snappy) { context.delete(snapshot) }
    }
}

/// A snapshot with the net worth at the end of its month.
struct SnapshotSummary: Identifiable {
    let snapshot: Snapshot
    let wealth: WealthPoint
    /// Net worth change since the previous snapshot.
    let change: Double?
    var id: PersistentIdentifier { snapshot.persistentModelID }
}

// MARK: - Charts

/// A titled card around a chart.
private struct ChartCard<Content: View>: View {
    let title: String
    var trailing: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.softInk)
                }
            }
            content
        }
        .card()
    }
}

private extension View {
    /// Axes, legend and height shared by the charts of this screen.
    func statsChartStyle() -> some View {
        self
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.compact)
                        }
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 190)
    }
}

private struct ChartHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.softInk)
    }
}

/// Net worth as a soft area, with what it's made of as thin lines.
private struct NetWorthChart: View {
    let points: [WealthPoint]
    let showsHome: Bool
    let showsLent: Bool

    private var scale: [(name: String, color: Color)] {
        var result = [(name: "Net worth", color: Theme.accent)]
        if showsHome || showsLent { result.append((name: "Investments", color: Theme.series[2])) }
        if showsHome { result.append((name: "Home equity", color: Theme.series[3])) }
        if showsLent { result.append((name: "Money lent", color: Theme.lent)) }
        return result
    }

    var body: some View {
        if points.count < 2 {
            ChartHint(text: "Take a few snapshots to see your net worth move.")
        } else {
            let showsParts = showsHome || showsLent
            Chart {
                ForEach(points) { point in
                    AreaMark(x: .value("Date", point.date), y: .value("Amount", point.netWorth))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.accent.opacity(0.18), Theme.accent.opacity(0.0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("Date", point.date), y: .value("Amount", point.netWorth),
                             series: .value("Series", "Net worth"))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .foregroundStyle(by: .value("Series", "Net worth"))
                    if showsParts {
                        LineMark(x: .value("Date", point.date), y: .value("Amount", point.investments),
                                 series: .value("Series", "Investments"))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .foregroundStyle(by: .value("Series", "Investments"))
                    }
                    if showsHome {
                        LineMark(x: .value("Date", point.date), y: .value("Amount", point.homeEquity),
                                 series: .value("Series", "Home equity"))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .foregroundStyle(by: .value("Series", "Home equity"))
                    }
                    if showsLent {
                        LineMark(x: .value("Date", point.date), y: .value("Amount", point.lent),
                                 series: .value("Series", "Money lent"))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .foregroundStyle(by: .value("Series", "Money lent"))
                    }
                }
            }
            .chartForegroundStyleScale(domain: scale.map { $0.name }, range: scale.map { $0.color })
            .statsChartStyle()
        }
    }
}

/// One amount of a stacked chart.
private struct StackRow: Identifiable {
    let date: Date
    let part: String
    let amount: Double
    var id: String { "\(date.timeIntervalSince1970)-\(part)" }
}

/// Amounts stacked as areas over time, with an optional line on top.
private struct StackedChart: View {
    let rows: [StackRow]
    var line: [StackRow] = []
    let scale: [(name: String, color: Color)]

    var body: some View {
        Chart {
            ForEach(rows) { row in
                AreaMark(x: .value("Date", row.date), y: .value("Amount", row.amount))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(by: .value("Part", row.part))
            }
            ForEach(line) { row in
                LineMark(x: .value("Date", row.date), y: .value("Amount", row.amount),
                         series: .value("Part", row.part))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(by: .value("Part", row.part))
            }
        }
        .chartForegroundStyleScale(domain: scale.map { $0.name }, range: scale.map { $0.color })
        .statsChartStyle()
    }
}

/// Where the monthly income goes, snapshot after snapshot: charges, savings
/// and what's left, under the income line.
private struct BudgetChart: View {
    let snapshots: [Snapshot]

    private var rows: [StackRow] {
        snapshots.flatMap { snapshot in
            [
                StackRow(date: snapshot.date, part: "Charges", amount: snapshot.charges),
                StackRow(date: snapshot.date, part: "Savings", amount: snapshot.savings),
                StackRow(date: snapshot.date, part: "Left", amount: max(snapshot.left, 0)),
            ]
        }
    }

    var body: some View {
        if snapshots.count < 2 {
            ChartHint(text: "Take a snapshot now and another one later to see how your income, charges and savings move.")
        } else {
            if let last = snapshots.last {
                HStack(spacing: 6) {
                    Chip(text: "Income \(last.income.currency)")
                    if last.savings > 0 {
                        Chip(text: "Saving \(last.savingsRate.formatted(.percent.precision(.fractionLength(0))))")
                    }
                }
            }
            StackedChart(
                rows: rows,
                line: snapshots.map { StackRow(date: $0.date, part: "Income", amount: $0.income) },
                scale: [
                    (name: "Charges", color: Theme.accent.opacity(0.75)),
                    (name: "Savings", color: Theme.series[1].opacity(0.75)),
                    (name: "Left", color: Theme.series[2].opacity(0.45)),
                    (name: "Income", color: Theme.ink),
                ]
            )
        }
    }
}

/// Recurring charges per category, snapshot after snapshot.
private struct ChargesChart: View {
    let snapshots: [Snapshot]

    var body: some View {
        if snapshots.count < 2 {
            ChartHint(text: "Take a snapshot now and another one later to see which charges go up or down.")
        } else {
            let lines: [(date: Date, lines: [SnapshotLine])] = snapshots.map { (date: $0.date, lines: $0.chargeLines) }
            let categories = ChargeCategory.allCases.filter { category in
                lines.contains { entry in entry.lines.contains { $0.category == category.rawValue } }
            }
            StackedChart(
                rows: Self.rows(lines, categories),
                scale: categories.enumerated().map { index, category in
                    (name: category.label, color: Theme.series[index % Theme.series.count].opacity(0.75))
                }
            )
        }
    }

    /// Every category at every date, so the areas stay continuous.
    private static func rows(_ lines: [(date: Date, lines: [SnapshotLine])],
                             _ categories: [ChargeCategory]) -> [StackRow] {
        var rows: [StackRow] = []
        for entry in lines {
            for category in categories {
                let amount = entry.lines
                    .filter { $0.category == category.rawValue }
                    .reduce(0) { $0 + $1.amount }
                rows.append(StackRow(date: entry.date, part: category.label, amount: amount))
            }
        }
        return rows
    }
}

// MARK: - Snapshots

private struct SnapshotSummaryRow: View {
    let summary: SnapshotSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.snapshot.date.monthName)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.softInk)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(summary.wealth.netWorth.currency)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                if let change = summary.change, change != 0 {
                    Chip(text: change.signedCurrency, color: Theme.gain(change),
                         background: Theme.gain(change).opacity(0.12))
                }
            }
        }
        .card(padding: 12)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts = ["left \(summary.snapshot.left.currency) a month"]
        if !summary.snapshot.note.isEmpty { parts.append(summary.snapshot.note) }
        return parts.joined(separator: " · ")
    }
}

/// Everything a snapshot saved, as it was that month.
struct SnapshotDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let summary: SnapshotSummary
    let showsHome: Bool
    /// Called when "Delete" is tapped; the sheet closes first.
    let onDelete: () -> Void

    var body: some View {
        let snapshot = summary.snapshot
        let wealth = summary.wealth
        let chargeLines = snapshot.chargeLines
        let incomeLines = snapshot.incomeLines
        NavigationStack {
            Form {
                if !snapshot.note.isEmpty {
                    Section("Note") { Text(snapshot.note) }
                }
                Section("Monthly budget") {
                    LabeledContent("Income", value: snapshot.income.currency)
                    LabeledContent("Recurring charges", value: snapshot.charges.currency)
                    LabeledContent("Savings", value: snapshot.savings.currency)
                    LabeledContent("Left") {
                        Text(snapshot.left.currency)
                            .foregroundStyle(snapshot.left >= 0 ? Theme.ink : Theme.negative)
                    }
                }
                Section("Net worth") {
                    LabeledContent("Investments", value: wealth.investments.currency)
                    if showsHome {
                        LabeledContent("Home equity", value: wealth.homeEquity.currency)
                    }
                    if wealth.lent > 0 {
                        LabeledContent("Money lent", value: wealth.lent.currency)
                    }
                    LabeledContent("Net worth", value: wealth.netWorth.currency)
                }
                if !incomeLines.isEmpty {
                    Section("Income") {
                        ForEach(Array(incomeLines.enumerated()), id: \.offset) { _, line in
                            LabeledContent(line.title, value: line.amount.currency)
                        }
                    }
                }
                if !chargeLines.isEmpty {
                    Section("Recurring charges") {
                        ForEach(Array(chargeLines.enumerated()), id: \.offset) { _, line in
                            LabeledContent(line.title, value: line.amount.currency)
                        }
                    }
                }
                Section {
                    Button("Delete this snapshot", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                } footer: {
                    Text("Also removes what investments, the home loan and money lent were worth that month.")
                }
            }
            .themedForm()
            .navigationTitle(snapshot.date.monthName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

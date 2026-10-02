import Charts
import SwiftData
import SwiftUI

struct InvestmentsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Investment.name) private var investments: [Investment]
    @State private var showingAdd = false
    @State private var showingSnapshot = false

    var body: some View {
        NavigationStack {
            List {
                if investments.isEmpty {
                    ContentUnavailableView(
                        "No investments",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Add a position with the + button, then record trades and price snapshots.")
                    )
                } else {
                    Section {
                        PortfolioSummary(investments: investments)
                    }
                    Section("Positions") {
                        ForEach(investments) { investment in
                            NavigationLink(value: investment) {
                                InvestmentRow(investment: investment)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(investments[index]) }
                        }
                    }
                }
            }
            .navigationTitle("Investments")
            .navigationDestination(for: Investment.self) { InvestmentDetailView(investment: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSnapshot = true
                    } label: {
                        Label("Snapshot all", systemImage: "camera")
                    }
                    .disabled(investments.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add investment", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { InvestmentFormView() }
            .sheet(isPresented: $showingSnapshot) { SnapshotAllView(investments: investments) }
        }
    }
}

private struct PortfolioSummary: View {
    let investments: [Investment]

    var body: some View {
        let value = investments.reduce(0) { $0 + $1.currentValue }
        let invested = investments.reduce(0) { $0 + $1.investedAmount }
        let gain = value - invested

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portfolio value").font(.caption).foregroundStyle(.secondary)
                Text(value.currency).font(.largeTitle.bold()).monospacedDigit()
            }
            HStack {
                StatTile(title: "Invested", value: invested.currency)
                StatTile(
                    title: "Gain",
                    value: invested > 0 ? "\(gain.signedCurrency) (\((gain / invested).signedPercent))" : gain.signedCurrency,
                    color: .gain(gain)
                )
            }
            HistoryChart(points: History.points(for: investments))
        }
        .padding(.vertical, 4)
    }
}

private struct InvestmentRow: View {
    let investment: Investment

    var body: some View {
        HStack {
            Image(systemName: investment.kind.icon)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading) {
                Text(investment.name).font(.headline)
                Text(investment.ticker.isEmpty ? investment.kind.rawValue : investment.ticker)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(investment.currentValue.currency).monospacedDigit()
                Text(investment.gainRatio.signedPercent)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.gain(investment.gain))
            }
        }
    }
}

/// Value vs. net invested amount over time.
struct HistoryChart: View {
    let points: [HistoryPoint]

    var body: some View {
        if points.count < 2 {
            Text("Record trades and snapshots on different days to see the evolution.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Amount", point.value),
                        series: .value("Series", "Value")
                    )
                    .foregroundStyle(by: .value("Series", "Value"))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Amount", point.invested),
                        series: .value("Series", "Invested")
                    )
                    .foregroundStyle(by: .value("Series", "Invested"))
                    .interpolationMethod(.stepEnd)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartForegroundStyleScale(["Value": Color.accentColor, "Invested": Color.gray])
            .frame(height: 180)
        }
    }
}

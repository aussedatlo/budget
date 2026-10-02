import Charts
import SwiftData
import SwiftUI

struct InvestmentsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Investment.name) private var investments: [Investment]
    @Query(sort: \Loan.name) private var loans: [Loan]
    @State private var showingAdd = false
    @State private var showingAddLoan = false
    @State private var showingSnapshot = false
    @State private var editing: Investment?
    @State private var confetti = 0

    /// Celebrate a portfolio in the green once per app launch.
    private static var celebrated = false

    private var value: Double { investments.reduce(0) { $0 + $1.currentValue } }
    private var invested: Double { investments.reduce(0) { $0 + $1.investedAmount } }
    private var gain: Double { value - invested }
    private var homeEquity: Double { loans.reduce(0) { $0 + $1.equity } }
    /// Investments + the part of the home that is ours.
    private var netWorth: Double { value + homeEquity }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if investments.isEmpty && loans.isEmpty {
                        emptyState
                    } else {
                        header
                        if !loans.isEmpty {
                            SectionTitle(title: "Our home")
                            ForEach(loans) { loan in
                                NavigationLink(value: loan) { LoanCard(loan: loan) }
                                    .buttonStyle(SquishyButtonStyle())
                            }
                        }
                        if !investments.isEmpty {
                            SectionTitle(title: "Our treasures")
                        }
                        ForEach(investments) { investment in
                            NavigationLink(value: investment) {
                                InvestmentCard(investment: investment)
                            }
                            .buttonStyle(SquishyButtonStyle())
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = investment }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    withAnimation(.bouncy) { context.delete(investment) }
                                }
                            }
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .animation(.bouncy, value: investments.count + loans.count)
            }
            .background(Theme.background)
            .navigationTitle("Our treasure")
            .navigationDestination(for: Investment.self) { InvestmentDetailView(investment: $0) }
            .navigationDestination(for: Loan.self) { LoanDetailView(loan: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSnapshot = true
                    } label: {
                        Label("Snapshot all", systemImage: "camera.fill")
                    }
                    .disabled(investments.isEmpty && loans.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add investment", systemImage: "sparkles") { showingAdd = true }
                        Button("Add home loan", systemImage: "house.fill") { showingAddLoan = true }
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .symbolEffect(.bounce, value: investments.count + loans.count)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { InvestmentFormView() }
            .sheet(isPresented: $showingAddLoan) { LoanFormView() }
            .sheet(isPresented: $showingSnapshot) { SnapshotAllView(investments: investments, loans: loans) }
            .sheet(item: $editing) { InvestmentFormView(investment: $0) }
            .overlay { ConfettiView(trigger: confetti).ignoresSafeArea() }
            .sensoryFeedback(.success, trigger: confetti)
            .onAppear {
                if gain > 0 && !Self.celebrated {
                    Self.celebrated = true
                    confetti += 1
                }
            }
            .onChange(of: netWorth) { old, new in
                // A new snapshot made us richer 🎉
                if new > old + 0.01 && gain > 0 { confetti += 1 }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("All that's ours 💎")
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
                Spacer()
                Text(gain >= 0 ? "🌱" : "🍂").font(.largeTitle)
            }
            FlowChips {
                if !investments.isEmpty {
                    Chip(text: "✨ Investments \(value.currency)")
                    Chip(
                        text: invested > 0 ? "\(gain.signedCurrency) · \((gain / invested).signedPercent)" : gain.signedCurrency,
                        color: Theme.gain(gain)
                    )
                }
                if !loans.isEmpty {
                    Chip(text: "🏠 Home \(homeEquity.currency)")
                }
            }
            if !investments.isEmpty {
                HistoryChart(points: History.points(for: investments))
            }
        }
        .card(LinearGradient(colors: [Theme.lavender, Theme.mint], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🌱").font(.system(size: 60))
            Text("Plant your first seed")
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
            Text("Add an ETF, some gold coins, crypto, a savings account or your home loan, then update it with a snapshot from time to time to watch it grow.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.softInk)
            HStack {
                Button("Add an investment") { showingAdd = true }
                    .buttonStyle(PillButtonStyle())
                Button("Add home loan") { showingAddLoan = true }
                    .buttonStyle(PillButtonStyle(color: Theme.positive))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .card()
        .padding(.top, 40)
    }
}

/// Chips that wrap to the next line when they don't fit.
private struct FlowChips<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { content }
            VStack(alignment: .leading, spacing: 6) { content }
        }
    }
}

private struct InvestmentCard: View {
    let investment: Investment

    var body: some View {
        HStack(spacing: 12) {
            EmojiBubble(emoji: investment.displayEmoji, color: investment.kind.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(investment.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(investment.ticker.isEmpty ? investment.kind.rawValue : "\(investment.ticker) · \(investment.kind.rawValue)")
                    .font(.caption)
                    .foregroundStyle(Theme.softInk)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(investment.currentValue.currency)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Chip(
                    text: investment.gainRatio.signedPercent,
                    color: Theme.gain(investment.gain),
                    background: Theme.gain(investment.gain).opacity(0.12)
                )
            }
        }
        .card(padding: 12)
        .contentShape(Rectangle())
    }
}

/// Value (soft gradient area) vs. net invested amount (dashed) over time.
struct HistoryChart: View {
    let points: [HistoryPoint]

    var body: some View {
        if points.count < 2 {
            Text("Record a few price snapshots to see it grow 📈")
                .font(.footnote)
                .foregroundStyle(Theme.softInk)
        } else {
            let low = points.map { min($0.value, $0.invested) }.min() ?? 0
            let high = points.map { max($0.value, $0.invested) }.max() ?? 1
            let padding = (high - low) * 0.1
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("Amount", low - padding),
                        yEnd: .value("Amount", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.accent.opacity(0.35), Theme.accent.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Amount", point.value),
                        series: .value("Series", "Value")
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(by: .value("Series", "Value"))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Amount", point.invested),
                        series: .value("Series", "Invested")
                    )
                    .interpolationMethod(.stepEnd)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(by: .value("Series", "Invested"))
                }
            }
            .chartForegroundStyleScale(["Value": Theme.accent, "Invested": Theme.softInk])
            .chartYScale(domain: (low - padding)...(high + padding))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 170)
        }
    }
}

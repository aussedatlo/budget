import Charts
import SwiftData
import SwiftUI

struct InvestmentsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Investment.name) private var investments: [Investment]
    @Query(sort: \Loan.name) private var loans: [Loan]
    @Query private var lendings: [Lending]
    @State private var showingAdd = false
    @State private var showingAddLoan = false
    @State private var showingSnapshot = false
    @State private var editing: Investment?
    @State private var confetti = 0
    /// Highest net worth seen so far: confetti only when it's beaten.
    @AppStorage("netWorthHigh") private var netWorthHigh: Double = 0
    @AppStorage("investmentsHigh") private var investmentsHigh: Double = 0
    /// Off: investments only. On: net worth, including the home, its loan and money lent.
    @AppStorage("includeHome") private var includeHome = false

    private var value: Double { investments.reduce(0) { $0 + $1.currentValue } }
    private var invested: Double { investments.reduce(0) { $0 + $1.investedAmount } }
    private var gain: Double { value - invested }
    private var homeEquity: Double { loans.reduce(0) { $0 + $1.equity } }
    /// Money lent that hasn't come back yet (detail on the Income tab).
    private var owed: Double { lendings.reduce(0) { $0 + $1.remaining } }
    /// Investments + the part of the home that is ours + money owed to us.
    private var netWorth: Double { value + homeEquity + owed }
    private var hasNetWorthExtras: Bool { !loans.isEmpty || owed > 0 }
    private var showsNetWorth: Bool { includeHome && hasNetWorthExtras }
    private var showsHome: Bool { showsNetWorth && !loans.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if investments.isEmpty && loans.isEmpty {
                        emptyState
                    } else {
                        header
                        if !investments.isEmpty {
                            SavingsChart(investments: investments)
                        }
                        if showsHome {
                            SectionTitle(title: "Home")
                            ForEach(loans) { loan in
                                NavigationLink(value: loan) { LoanCard(loan: loan) }
                                    .buttonStyle(SquishyButtonStyle())
                            }
                        }
                        if !investments.isEmpty {
                            SectionTitle(title: "Investments")
                        }
                        ForEach(investments) { investment in
                            NavigationLink(value: investment) {
                                InvestmentCard(investment: investment)
                            }
                            .buttonStyle(SquishyButtonStyle())
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = investment }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    withAnimation(.snappy) { context.delete(investment) }
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .animation(.snappy, value: investments.count + loans.count)
            }
            .background(Theme.background)
            .navigationTitle("Investments")
            .navigationDestination(for: Investment.self) { InvestmentDetailView(investment: $0) }
            .navigationDestination(for: Loan.self) { LoanDetailView(loan: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSnapshot = true
                    } label: {
                        Label("Snapshot all", systemImage: "camera")
                    }
                    .disabled(investments.isEmpty && loans.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add investment", systemImage: "chart.line.uptrend.xyaxis") { showingAdd = true }
                        Button("Add home loan", systemImage: "house") { showingAddLoan = true }
                    } label: {
                        Label("Add", systemImage: "plus")
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
                if netWorthHigh == 0 { netWorthHigh = netWorth }
                if investmentsHigh == 0 { investmentsHigh = value }
            }
            // A small celebration only for a new all-time high of what's shown
            .onChange(of: netWorth) { old, new in
                netWorthHigh = celebrateIfNewHigh(old: old, new: new, high: netWorthHigh, shown: showsNetWorth)
            }
            .onChange(of: value) { old, new in
                investmentsHigh = celebrateIfNewHigh(old: old, new: new, high: investmentsHigh, shown: !showsNetWorth)
            }
        }
    }

    /// Fires the confetti when `new` beats the high while shown; returns the new high.
    private func celebrateIfNewHigh(old: Double, new: Double, high: Double, shown: Bool) -> Double {
        guard new > old + 0.01 else { return high }
        if shown && high > 0 && new > high + 0.01 { confetti += 1 }
        return max(high, new)
    }

    private var header: some View {
        let total = showsNetWorth ? netWorth : value
        return VStack(alignment: .leading, spacing: 12) {
            if hasNetWorthExtras {
                Picker("Show", selection: $includeHome.animation(.snappy)) {
                    Text("Investments").tag(false)
                    Text("Net worth").tag(true)
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(showsNetWorth ? "Net worth" : "Investments value")
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
                Text(total.currency)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: total))
                    .animation(.snappy, value: total)
            }
            FlowChips {
                if showsNetWorth {
                    Chip(text: "Investments \(value.currency)")
                    if !loans.isEmpty { Chip(text: "Home equity \(homeEquity.currency)") }
                    if owed > 0 { Chip(text: "Money lent \(owed.currency)") }
                } else if !investments.isEmpty {
                    Chip(text: "Invested \(invested.currency)")
                }
                if !investments.isEmpty {
                    Chip(
                        text: invested > 0 ? "\(gain.signedCurrency) · \((gain / invested).signedPercent)" : gain.signedCurrency,
                        color: Theme.gain(gain)
                    )
                }
            }
            if !investments.isEmpty {
                HistoryChart(points: History.points(for: investments))
            }
        }
        .card()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No investments yet")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Add an ETF, gold coins, crypto, a savings account or your home loan, then update it with a snapshot from time to time.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.softInk)
            HStack {
                Button("Add an investment") { showingAdd = true }
                    .buttonStyle(PillButtonStyle())
                Button("Add home loan") { showingAddLoan = true }
                    .buttonStyle(PillButtonStyle(color: Theme.ink))
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
            Text("Add a few snapshots to see the evolution.")
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
                        LinearGradient(colors: [Theme.accent.opacity(0.18), Theme.accent.opacity(0.0)],
                                       startPoint: .top, endPoint: .bottom)
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Amount", point.value),
                        series: .value("Series", "Value")
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
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

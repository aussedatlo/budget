import Charts
import SwiftData
import SwiftUI

struct InvestmentsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Investment.name) private var investments: [Investment]
    @Query(sort: \Loan.name) private var loans: [Loan]
    @Query private var lendings: [Lending]
    @Binding var showingSnapshot: Bool
    @State private var showingAdd = false
    @State private var showingAddLoan = false
    @State private var editing: Investment?
    @State private var deleting: Investment?
    @State private var confetti = 0
    /// Highest net worth seen so far: confetti only when it's beaten.
    @AppStorage("netWorthHigh") private var netWorthHigh: Double = 0
    @AppStorage("investmentsHigh") private var investmentsHigh: Double = 0
    /// Off: investments only. On: net worth, including the home, its loan and money lent.
    @AppStorage("includeHome") private var includeHome = false
    /// Investments left out of the totals for a while.
    private let hiddenInvestments = HiddenInvestments.shared

    private var counted: [Investment] { investments.filter { !hiddenInvestments.contains($0) } }
    private var hiddenCount: Int { investments.count - counted.count }

    private var value: Double { counted.reduce(0) { $0 + $1.currentValue } }
    private var invested: Double { counted.reduce(0) { $0 + $1.investedAmount } }
    private var gain: Double { value - invested }
    private var homeEquity: Double { loans.reduce(0) { $0 + $1.equity } }
    /// Money lent that hasn't come back yet (detail on the Income tab).
    private var owed: Double { lendings.reduce(0) { $0 + $1.remaining } }
    /// Investments + the part of the home that is ours + money owed to us.
    private var netWorth: Double { value + homeEquity + owed }
    /// Highs follow everything owned, so hiding or showing an investment never sets one off.
    private var fullValue: Double { investments.reduce(0) { $0 + $1.currentValue } }
    private var fullNetWorth: Double { fullValue + homeEquity + owed }
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
                            .overlay(alignment: .trailing) { EyeButton(investment: investment) }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = investment }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleting = investment
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
            .navigationTitle("Wealth")
            .navigationDestination(for: Investment.self) { InvestmentDetailView(investment: $0) }
            .navigationDestination(for: Loan.self) { LoanDetailView(loan: $0) }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    SnapshotButton(isPresented: $showingSnapshot)
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
            .sheet(item: $editing) { InvestmentFormView(investment: $0) }
            .confirmDelete($deleting, title: { "Delete \($0.name)?" },
                           message: { _ in "Its whole history goes too." }) { investment in
                withAnimation(.snappy) { context.delete(investment) }
            }
            .overlay { ConfettiView(trigger: confetti).ignoresSafeArea() }
            .sensoryFeedback(.success, trigger: confetti)
            .onAppear {
                if netWorthHigh == 0 { netWorthHigh = fullNetWorth }
                if investmentsHigh == 0 { investmentsHigh = fullValue }
            }
            // A small celebration only for a new all-time high of what's shown
            .onChange(of: fullNetWorth) { old, new in
                netWorthHigh = celebrateIfNewHigh(old: old, new: new, high: netWorthHigh, shown: showsNetWorth)
            }
            .onChange(of: fullValue) { old, new in
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
            HStack(alignment: .center, spacing: 18) {
                GrowingSeedlingView(pops: confetti)
                    .frame(width: 100)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(showsNetWorth ? "Net worth" : "Investments value")
                            .font(.subheadline)
                            .foregroundStyle(Theme.softInk)
                        Spacer()
                        if hasNetWorthExtras {
                            NetWorthButton(isOn: $includeHome)
                        }
                    }
                    Text(total.currency)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: total))
                        .animation(.snappy, value: total)
                        .accessibilityIdentifier("wealth-total")
                }
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
                if hiddenCount > 0 {
                    Chip(text: "\(hiddenCount) hidden", color: Theme.softInk)
                }
            }
        }
        .card()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No investments yet")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Add an ETF, gold coins, crypto, a savings account or your home loan, then update what it's worth from time to time.")
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
struct FlowChips<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { content }
            VStack(alignment: .leading, spacing: 6) { content }
        }
    }
}

/// Investments left out of the Wealth totals, kept in settings rather than in the stored data,
/// and observed by every view that shows them.
@Observable
final class HiddenInvestments {
    static let key = "hiddenInvestments"
    static let shared = HiddenInvestments()

    private(set) var ids: Set<PersistentIdentifier>

    private init() {
        let data = UserDefaults.standard.data(forKey: Self.key) ?? Data()
        ids = (try? JSONDecoder().decode(Set<PersistentIdentifier>.self, from: data)) ?? []
    }

    func contains(_ investment: Investment) -> Bool { ids.contains(investment.persistentModelID) }

    func toggle(_ investment: Investment) {
        if contains(investment) { ids.remove(investment.persistentModelID) } else { ids.insert(investment.persistentModelID) }
        UserDefaults.standard.set(try? JSONEncoder().encode(ids), forKey: Self.key)
    }
}

/// The bank next to the header title: adds the home and money lent to the total, or takes them out.
private struct NetWorthButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            Image(systemName: isOn ? "building.columns.fill" : "building.columns")
                .font(.subheadline)
                .foregroundStyle(isOn ? Theme.accent : Theme.softInk)
                .frame(width: 48, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Keep the tap area without making the header taller
        .padding(.vertical, -12)
        .padding(.trailing, -14)
        .accessibilityLabel(isOn ? "Show investments only" : "Show net worth")
        .accessibilityIdentifier("net-worth-toggle")
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

/// The eye on each card: hides the investment from the totals, or shows it again.
private struct EyeButton: View {
    let investment: Investment
    private let hiddenInvestments = HiddenInvestments.shared

    var body: some View {
        let isHidden = hiddenInvestments.contains(investment)
        Button {
            withAnimation(.snappy) { hiddenInvestments.toggle(investment) }
        } label: {
            Image(systemName: isHidden ? "eye.slash" : "eye")
                .font(.subheadline)
                .foregroundStyle(isHidden ? Theme.accent : Theme.softInk)
                .frame(width: 48, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isHidden ? "Show \(investment.name)" : "Hide \(investment.name)")
        .accessibilityIdentifier("investment-eye-\(investment.name)")
        .sensoryFeedback(.selection, trigger: isHidden)
    }
}

private struct InvestmentCard: View {
    let investment: Investment
    private let hiddenInvestments = HiddenInvestments.shared
    /// Left out of the totals: dimmed, still listed.
    private var isHidden: Bool { hiddenInvestments.contains(investment) }

    var body: some View {
        HStack(spacing: 12) {
            EmojiBubble(emoji: investment.displayEmoji, color: investment.kind.color)
                .opacity(isHidden ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(investment.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(investment.ticker.isEmpty ? investment.kind.rawValue : "\(investment.ticker) · \(investment.kind.rawValue)")
                    .font(.caption)
                    .foregroundStyle(Theme.softInk)
            }
            .opacity(isHidden ? 0.45 : 1)
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
            .opacity(isHidden ? 0.45 : 1)
            // Room for the eye button laid over the card
            Color.clear.frame(width: 24)
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
            Text("Take a few snapshots to see the evolution.")
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

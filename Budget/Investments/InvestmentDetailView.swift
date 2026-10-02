import SwiftData
import SwiftUI

struct InvestmentDetailView: View {
    @Environment(\.modelContext) private var context
    let investment: Investment

    @State private var showingEdit = false
    @State private var addingTrade = false
    @State private var addingSnapshot = false
    @State private var editingTrade: Trade?
    @State private var editingSnapshot: PriceSnapshot?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                LazyVGrid(columns: columns, spacing: 10) {
                    tile("🧺", "Quantity", investment.currentQuantity.quantityText, Theme.butter)
                    tile("🏷️", "Avg. buy price", investment.averageBuyPrice?.currency ?? "–", Theme.sky)
                    tile("💸", "Last price", investment.price()?.currency ?? "–", Theme.peach)
                    tile(
                        "📅", "Updated",
                        investment.lastPriceDate?.formatted(date: .abbreviated, time: .omitted) ?? "–",
                        Theme.lavender
                    )
                }

                HistoryChart(points: History.points(for: [investment]))
                    .card()

                SectionTitle(title: "Trades")
                ForEach(investment.sortedTrades) { trade in
                    Button { editingTrade = trade } label: { TradeRow(trade: trade) }
                        .buttonStyle(SquishyButtonStyle())
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(trade) }
                        }
                }
                Button("Add trade", systemImage: "plus") { addingTrade = true }
                    .buttonStyle(PillButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)

                SectionTitle(title: "Price snapshots")
                ForEach(investment.sortedSnapshots) { snapshot in
                    Button { editingSnapshot = snapshot } label: {
                        SnapshotRow(snapshot: snapshot, quantity: investment.quantity(at: snapshot.date))
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { delete(snapshot) }
                    }
                }
                Button("Add snapshot", systemImage: "camera.fill") { addingSnapshot = true }
                    .buttonStyle(PillButtonStyle(color: Theme.positive))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .animation(.bouncy, value: investment.trades.count + investment.snapshots.count)
        }
        .background(Theme.background)
        .navigationTitle(investment.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { showingEdit = true }
        }
        .sheet(isPresented: $showingEdit) { InvestmentFormView(investment: investment) }
        .sheet(isPresented: $addingTrade) { TradeFormView(investment: investment) }
        .sheet(isPresented: $addingSnapshot) { SnapshotFormView(investment: investment) }
        .sheet(item: $editingTrade) { TradeFormView(investment: investment, trade: $0) }
        .sheet(item: $editingSnapshot) { SnapshotFormView(investment: investment, snapshot: $0) }
        .sensoryFeedback(.success, trigger: investment.trades.count + investment.snapshots.count) { old, new in
            new > old
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            EmojiBubble(emoji: investment.displayEmoji, color: Theme.card.opacity(0.7), size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(investment.currentValue.currency)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: investment.currentValue))
                    .animation(.snappy, value: investment.currentValue)
                Text("Invested \(investment.investedAmount.currency)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
                Chip(
                    text: "\(investment.gain.signedCurrency) · \(investment.gainRatio.signedPercent)",
                    color: Theme.gain(investment.gain)
                )
            }
        }
        .card(LinearGradient(colors: [investment.kind.color, Theme.pink],
                             startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func tile(_ emoji: String, _ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emoji).font(.title3)
            StatTile(title: title, value: value)
        }
        .card(color, padding: 12)
    }

    private func delete(_ trade: Trade) {
        withAnimation(.bouncy) {
            investment.trades.removeAll { $0 == trade }
            context.delete(trade)
        }
    }

    private func delete(_ snapshot: PriceSnapshot) {
        withAnimation(.bouncy) {
            investment.snapshots.removeAll { $0 == snapshot }
            context.delete(snapshot)
        }
    }
}

private struct TradeRow: View {
    let trade: Trade

    var body: some View {
        HStack(spacing: 12) {
            EmojiBubble(emoji: trade.isSale ? "📤" : "📥", color: trade.isSale ? Theme.peach : Theme.mint, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(trade.isSale ? "Sell" : "Buy")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(trade.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Theme.softInk)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(abs(trade.cashFlow).currency)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("\(trade.quantity.quantityText) × \(trade.unitPrice.currency)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.softInk)
            }
        }
        .card(padding: 12)
        .contentShape(Rectangle())
    }
}

private struct SnapshotRow: View {
    let snapshot: PriceSnapshot
    let quantity: Double

    var body: some View {
        HStack(spacing: 12) {
            EmojiBubble(emoji: "📸", color: Theme.lavender, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                if !snapshot.note.isEmpty {
                    Text(snapshot.note).font(.caption).foregroundStyle(Theme.softInk)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(snapshot.unitPrice.currency)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("Value \((quantity * snapshot.unitPrice).currency)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.softInk)
            }
        }
        .card(padding: 12)
        .contentShape(Rectangle())
    }
}

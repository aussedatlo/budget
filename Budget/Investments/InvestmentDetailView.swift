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

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatTile(title: "Value", value: investment.currentValue.currency)
                        StatTile(title: "Invested", value: investment.investedAmount.currency)
                    }
                    HStack {
                        StatTile(title: "Gain", value: investment.gain.signedCurrency, color: .gain(investment.gain))
                        StatTile(title: "Performance", value: investment.gainRatio.signedPercent, color: .gain(investment.gain))
                    }
                    HStack {
                        StatTile(title: "Quantity", value: investment.currentQuantity.quantityText)
                        StatTile(title: "Avg. buy price", value: investment.averageBuyPrice?.currency ?? "–")
                    }
                    HStack {
                        StatTile(title: "Last price", value: investment.price()?.currency ?? "–")
                        StatTile(
                            title: "Updated",
                            value: investment.lastPriceDate?.formatted(date: .abbreviated, time: .omitted) ?? "–"
                        )
                    }
                    HistoryChart(points: History.points(for: [investment]))
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(investment.sortedTrades) { trade in
                    Button { editingTrade = trade } label: { TradeRow(trade: trade) }
                        .tint(.primary)
                }
                .onDelete { offsets in
                    let items = offsets.map { investment.sortedTrades[$0] }
                    for item in items {
                        investment.trades.removeAll { $0 == item }
                        context.delete(item)
                    }
                }
                Button("Add trade", systemImage: "plus") { addingTrade = true }
            } header: {
                Text("Trades")
            } footer: {
                Text("Buys and sells: how much you put in and at what price.")
            }

            Section {
                ForEach(investment.sortedSnapshots) { snapshot in
                    Button { editingSnapshot = snapshot } label: {
                        SnapshotRow(snapshot: snapshot, quantity: investment.quantity(at: snapshot.date))
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    let items = offsets.map { investment.sortedSnapshots[$0] }
                    for item in items {
                        investment.snapshots.removeAll { $0 == item }
                        context.delete(item)
                    }
                }
                Button("Add snapshot", systemImage: "camera") { addingSnapshot = true }
            } header: {
                Text("Price snapshots")
            } footer: {
                Text("Record the unit price regularly to follow the value over time.")
            }
        }
        .navigationTitle(investment.name)
        .toolbar {
            Button("Edit") { showingEdit = true }
        }
        .sheet(isPresented: $showingEdit) { InvestmentFormView(investment: investment) }
        .sheet(isPresented: $addingTrade) { TradeFormView(investment: investment) }
        .sheet(isPresented: $addingSnapshot) { SnapshotFormView(investment: investment) }
        .sheet(item: $editingTrade) { TradeFormView(investment: investment, trade: $0) }
        .sheet(item: $editingSnapshot) { SnapshotFormView(investment: investment, snapshot: $0) }
    }
}

private struct TradeRow: View {
    let trade: Trade

    var body: some View {
        HStack {
            Image(systemName: trade.isSale ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                .foregroundStyle(trade.isSale ? .orange : .blue)
            VStack(alignment: .leading) {
                Text(trade.isSale ? "Sell" : "Buy").font(.subheadline.bold())
                Text(trade.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(abs(trade.cashFlow).currency).monospacedDigit()
                Text("\(trade.quantity.quantityText) × \(trade.unitPrice.currency)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct SnapshotRow: View {
    let snapshot: PriceSnapshot
    let quantity: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(snapshot.date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
                if !snapshot.note.isEmpty {
                    Text(snapshot.note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(snapshot.unitPrice.currency).monospacedDigit()
                Text("Value \((quantity * snapshot.unitPrice).currency)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

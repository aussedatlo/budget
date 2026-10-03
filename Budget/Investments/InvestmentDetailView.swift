import SwiftData
import SwiftUI

struct InvestmentDetailView: View {
    let investment: Investment

    @State private var showingEdit = false
    @State private var adding = false
    @State private var editing: ValueSnapshot?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                LazyVGrid(columns: columns, spacing: 10) {
                    if let latest = investment.latest, latest.tracksUnits {
                        tile("Quantity", (latest.quantity ?? 0).quantityText)
                        tile("Unit price", (latest.unitPrice ?? 0).currency)
                    }
                    tile("Invested so far", investment.investedAmount.currency)
                    tile("Updated", investment.latest?.date.formatted(date: .abbreviated, time: .omitted) ?? "–")
                }

                HistoryChart(points: History.points(for: [investment]))
                    .card()

                HStack {
                    SectionTitle(title: "History")
                    Button("Update values", systemImage: "pencil") { adding = true }
                        .buttonStyle(PillButtonStyle())
                }
                let history = investment.sortedHistory
                ForEach(Array(history.enumerated()), id: \.element.id) { index, snapshot in
                    Button { editing = snapshot } label: {
                        SnapshotRow(
                            snapshot: snapshot,
                            previous: index + 1 < history.count ? history[index + 1] : nil
                        )
                    }
                    .buttonStyle(SquishyButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .animation(.snappy, value: investment.history.count)
        }
        .background(Theme.background)
        .navigationTitle(investment.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { showingEdit = true }
        }
        .sheet(isPresented: $showingEdit) { InvestmentFormView(investment: investment) }
        .sheet(isPresented: $adding) { SnapshotFormView(investment: investment) }
        .sheet(item: $editing) { SnapshotFormView(investment: investment, snapshot: $0) }
        .sensoryFeedback(.success, trigger: investment.history.count) { old, new in new > old }
    }

    private var header: some View {
        HStack(spacing: 14) {
            EmojiBubble(emoji: investment.displayEmoji, color: investment.kind.color, size: 56)
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
        .card()
    }

    private func tile(_ title: String, _ value: String) -> some View {
        StatTile(title: title, value: value)
            .card(padding: 12)
    }
}

/// The values on a day, with how much they moved since the previous ones.
private struct SnapshotRow: View {
    let snapshot: ValueSnapshot
    let previous: ValueSnapshot?

    private var change: Double? { previous.map { snapshot.value - $0.value } }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.softInk)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(snapshot.value.currency)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                if let change, change != 0 {
                    Chip(text: change.signedCurrency, color: Theme.gain(change),
                         background: Theme.gain(change).opacity(0.12))
                }
            }
        }
        .card(padding: 12)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if let quantity = snapshot.quantity, let unitPrice = snapshot.unitPrice {
            parts.append("\(quantity.quantityText) × \(unitPrice.currency)")
        }
        parts.append("invested \(snapshot.invested.currency)")
        if !snapshot.note.isEmpty { parts.append(snapshot.note) }
        return parts.joined(separator: " · ")
    }
}

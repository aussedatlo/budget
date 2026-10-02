import SwiftData
import SwiftUI

// MARK: - Investment

struct InvestmentFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let investment: Investment?

    @State private var name: String
    @State private var ticker: String
    @State private var kind: InvestmentKind
    // Optional first purchase, only when creating.
    @State private var quantity: Double?
    @State private var unitPrice: Double?
    @State private var date = Date.now

    init(investment: Investment? = nil) {
        self.investment = investment
        _name = State(initialValue: investment?.name ?? "")
        _ticker = State(initialValue: investment?.ticker ?? "")
        _kind = State(initialValue: investment?.kind ?? .etf)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. MSCI World)", text: $name)
                    TextField("Ticker (optional)", text: $ticker)
                        .textInputAutocapitalization(.characters)
                    Picker("Type", selection: $kind) {
                        ForEach(InvestmentKind.allCases) { kind in
                            Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                        }
                    }
                }
                if investment == nil {
                    Section {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                        NumberField(title: "Quantity", value: $quantity)
                        NumberField(title: "Unit price", value: $unitPrice)
                    } header: {
                        Text("First purchase (optional)")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(investment == nil ? "New investment" : "Edit investment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let investment {
            investment.name = trimmed
            investment.ticker = ticker
            investment.kind = kind
        } else {
            let new = Investment(name: trimmed, ticker: ticker, kind: kind)
            context.insert(new)
            if let quantity, let unitPrice, quantity > 0 {
                let trade = Trade(date: date, quantity: quantity, unitPrice: unitPrice)
                context.insert(trade)
                new.trades.append(trade)
            }
        }
        dismiss()
    }
}

// MARK: - Trade

struct TradeFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let investment: Investment
    let trade: Trade?

    @State private var isSale: Bool
    @State private var date: Date
    @State private var quantity: Double?
    @State private var unitPrice: Double?
    @State private var fees: Double?
    @State private var note: String

    init(investment: Investment, trade: Trade? = nil) {
        self.investment = investment
        self.trade = trade
        _isSale = State(initialValue: trade?.isSale ?? false)
        _date = State(initialValue: trade?.date ?? .now)
        _quantity = State(initialValue: trade?.quantity)
        _unitPrice = State(initialValue: trade?.unitPrice ?? investment.price())
        _fees = State(initialValue: trade.flatMap { $0.fees == 0 ? nil : $0.fees })
        _note = State(initialValue: trade?.note ?? "")
    }

    private var total: Double {
        let gross = (quantity ?? 0) * (unitPrice ?? 0)
        return isSale ? gross - (fees ?? 0) : gross + (fees ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isSale) {
                        Text("Buy").tag(false)
                        Text("Sell").tag(true)
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    NumberField(title: "Quantity", value: $quantity)
                    NumberField(title: "Unit price", value: $unitPrice)
                    NumberField(title: "Fees", value: $fees)
                }
                Section {
                    LabeledContent(isSale ? "Amount received" : "Amount used", value: total.currency)
                    TextField("Note", text: $note)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(trade == nil ? "New trade" : "Edit trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled((quantity ?? 0) <= 0 || unitPrice == nil)
                }
            }
        }
    }

    private func save() {
        let item = trade ?? Trade()
        item.isSale = isSale
        item.date = date
        item.quantity = quantity ?? 0
        item.unitPrice = unitPrice ?? 0
        item.fees = fees ?? 0
        item.note = note
        if trade == nil {
            context.insert(item)
            investment.trades.append(item)
        }
        dismiss()
    }
}

// MARK: - Snapshot

struct SnapshotFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let investment: Investment
    let snapshot: PriceSnapshot?

    @State private var date: Date
    @State private var unitPrice: Double?
    @State private var note: String

    init(investment: Investment, snapshot: PriceSnapshot? = nil) {
        self.investment = investment
        self.snapshot = snapshot
        _date = State(initialValue: snapshot?.date ?? .now)
        _unitPrice = State(initialValue: snapshot?.unitPrice ?? investment.price())
        _note = State(initialValue: snapshot?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    NumberField(title: "Unit price", value: $unitPrice)
                    TextField("Note", text: $note)
                }
                Section {
                    LabeledContent("Quantity held", value: investment.quantity(at: date).quantityText)
                    LabeledContent("Value", value: (investment.quantity(at: date) * (unitPrice ?? 0)).currency)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(snapshot == nil ? "New snapshot" : "Edit snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(unitPrice == nil)
                }
            }
        }
    }

    private func save() {
        let item = snapshot ?? PriceSnapshot()
        item.date = date
        item.unitPrice = unitPrice ?? 0
        item.note = note
        if snapshot == nil {
            context.insert(item)
            investment.snapshots.append(item)
        }
        dismiss()
    }
}

/// Records a price for every investment at once.
struct SnapshotAllView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let investments: [Investment]

    @State private var date = Date.now
    @State private var prices: [PersistentIdentifier: Double] = [:]

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Section {
                    ForEach(investments) { investment in
                        NumberField(
                            title: investment.name,
                            value: Binding(
                                get: { prices[investment.persistentModelID] },
                                set: { prices[investment.persistentModelID] = $0 }
                            )
                        )
                    }
                } header: {
                    Text("Unit prices")
                } footer: {
                    Text("Pre-filled with the last known price. Leave empty to skip a position.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .onAppear {
                for investment in investments {
                    prices[investment.persistentModelID] = investment.price()
                }
            }
        }
    }

    private func save() {
        for investment in investments {
            guard let price = prices[investment.persistentModelID], price > 0 else { continue }
            let snapshot = PriceSnapshot(date: date, unitPrice: price)
            context.insert(snapshot)
            investment.snapshots.append(snapshot)
        }
        dismiss()
    }
}

// MARK: - Shared

/// A labeled decimal field with an optional value (empty = nil).
struct NumberField: View {
    let title: String
    @Binding var value: Double?

    var body: some View {
        LabeledContent(title) {
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}

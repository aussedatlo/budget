import SwiftData
import SwiftUI

/// Monthly income minus recurring charges: what's left each month.
struct MonthlyView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FixedCharge.dayOfMonth) private var charges: [FixedCharge]
    @AppStorage(AppSettings.incomeKey) private var income: Double = 0
    @Binding var showingSettings: Bool
    @State private var adding = false
    @State private var editing: FixedCharge?

    private var total: Double { charges.reduce(0) { $0 + $1.amount } }
    private var left: Double { income - total }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summary
                    LabeledContent("Monthly income") {
                        TextField("0", value: $income, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .accessibilityIdentifier("monthly-income")
                    }
                }

                Section {
                    if charges.isEmpty {
                        Text("Add rent, subscriptions, insurance… anything paid every month.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(charges) { charge in
                        Button { editing = charge } label: { ChargeRow(charge: charge) }
                            .tint(.primary)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(charges[index]) }
                    }
                } header: {
                    HStack {
                        Text("Recurring charges")
                        Spacer()
                        Text(total.currency)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Monthly")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: {
                        Label("Add charge", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $adding) { FixedChargeFormView() }
            .sheet(item: $editing) { FixedChargeFormView(charge: $0) }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Left each month").font(.caption).foregroundStyle(.secondary)
                Text(left.currency)
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(income > 0 ? Color.gain(left) : Color.primary)
            }
            if income > 0 {
                ProgressView(value: min(total, income), total: income)
                    .tint(left < 0 ? Color.red : total > income * 0.8 ? Color.orange : Color.green)
            }
            HStack {
                StatTile(title: "Income", value: income.currency)
                StatTile(title: "Recurring", value: total.currency)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ChargeRow: View {
    let charge: FixedCharge

    var body: some View {
        HStack {
            Image(systemName: charge.category.icon)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(charge.category.color, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading) {
                Text(charge.title)
                Text("Day \(charge.dayOfMonth)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(charge.amount.currency).monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

struct FixedChargeFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let charge: FixedCharge?

    @State private var title: String
    @State private var amount: Double?
    @State private var category: ChargeCategory
    @State private var dayOfMonth: Int

    init(charge: FixedCharge? = nil) {
        self.charge = charge
        _title = State(initialValue: charge?.title ?? "")
        _amount = State(initialValue: charge?.amount)
        _category = State(initialValue: charge?.category ?? .housing)
        _dayOfMonth = State(initialValue: charge?.dayOfMonth ?? 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (e.g. Rent)", text: $title)
                        .accessibilityIdentifier("charge-title")
                    NumberField(title: "Amount", value: $amount, identifier: "charge-amount")
                    Picker("Category", selection: $category) {
                        ForEach(ChargeCategory.allCases) { category in
                            Label(category.label, systemImage: category.icon).tag(category)
                        }
                    }
                    Stepper("Day of month: \(dayOfMonth)", value: $dayOfMonth, in: 1...31)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(charge == nil ? "New charge" : "Edit charge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || (amount ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        let item = charge ?? FixedCharge(title: "", amount: 0)
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.amount = amount ?? 0
        item.category = category
        item.dayOfMonth = dayOfMonth
        if charge == nil { context.insert(item) }
        dismiss()
    }
}

import SwiftData
import SwiftUI

struct ExpenseFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let expense: Expense?

    @State private var amount: Double?
    @State private var title: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var note: String
    @FocusState private var amountFocused: Bool

    init(expense: Expense? = nil, defaultDate: Date = .now) {
        self.expense = expense
        _amount = State(initialValue: expense?.amount)
        _title = State(initialValue: expense?.title ?? "")
        _category = State(initialValue: expense?.category ?? .food)
        _date = State(initialValue: expense?.date ?? defaultDate)
        _note = State(initialValue: expense?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                        .focused($amountFocused)
                    TextField("Title (e.g. Groceries)", text: $title)
                }
                Section {
                    CategoryPicker(selection: $category)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note", text: $note, axis: .vertical)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(expense == nil ? "New expense" : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled((amount ?? 0) <= 0)
                }
            }
            .onAppear { if expense == nil { amountFocused = true } }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if let expense {
            expense.amount = amount ?? 0
            expense.title = trimmed
            expense.category = category
            expense.date = date
            expense.note = note
        } else {
            context.insert(Expense(title: trimmed, amount: amount ?? 0, date: date, category: category, note: note))
        }
        dismiss()
    }
}

struct CategoryPicker: View {
    @Binding var selection: ExpenseCategory

    var body: some View {
        Picker("Category", selection: $selection) {
            ForEach(ExpenseCategory.allCases) { category in
                Label(category.label, systemImage: category.icon).tag(category)
            }
        }
    }
}

// MARK: - Fixed charges

struct FixedChargesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FixedCharge.dayOfMonth) private var charges: [FixedCharge]
    @State private var adding = false
    @State private var editing: FixedCharge?

    private var active: [FixedCharge] { charges.filter(\.isActive) }
    private var stopped: [FixedCharge] { charges.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if active.isEmpty {
                        Text("Rent, subscriptions, insurance… anything paid every month.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(active) { row($0) }
                        .onDelete { offsets in
                            for index in offsets { context.delete(active[index]) }
                        }
                } header: {
                    HStack {
                        Text("Active")
                        Spacer()
                        Text(active.reduce(0) { $0 + $1.amount }.currency)
                    }
                }
                if !stopped.isEmpty {
                    Section("Stopped") {
                        ForEach(stopped) { row($0) }
                            .onDelete { offsets in
                                for index in offsets { context.delete(stopped[index]) }
                            }
                    }
                }
            }
            .navigationTitle("Fixed charges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Label("Add", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $adding) { FixedChargeFormView() }
            .sheet(item: $editing) { FixedChargeFormView(charge: $0) }
        }
    }

    private func row(_ charge: FixedCharge) -> some View {
        Button { editing = charge } label: {
            ExpenseRowContent(
                title: charge.title,
                subtitle: charge.endDate.map { "Stopped \($0.formatted(date: .abbreviated, time: .omitted))" }
                    ?? "Day \(charge.dayOfMonth) of each month",
                amount: charge.amount,
                category: charge.category
            )
        }
        .tint(.primary)
    }
}

struct FixedChargeFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let charge: FixedCharge?

    @State private var title: String
    @State private var amount: Double?
    @State private var category: ExpenseCategory
    @State private var dayOfMonth: Int
    @State private var startDate: Date
    @State private var isActive: Bool

    init(charge: FixedCharge? = nil) {
        self.charge = charge
        _title = State(initialValue: charge?.title ?? "")
        _amount = State(initialValue: charge?.amount)
        _category = State(initialValue: charge?.category ?? .housing)
        _dayOfMonth = State(initialValue: charge?.dayOfMonth ?? 1)
        _startDate = State(initialValue: charge?.startDate ?? .now)
        _isActive = State(initialValue: charge?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (e.g. Rent)", text: $title)
                    NumberField(title: "Amount", value: $amount)
                    CategoryPicker(selection: $category)
                }
                Section {
                    Stepper("Day of month: \(dayOfMonth)", value: $dayOfMonth, in: 1...31)
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    if charge != nil {
                        Toggle("Active", isOn: $isActive)
                    }
                } footer: {
                    Text("Stopping a charge keeps it in previous months.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(charge == nil ? "New fixed charge" : "Edit fixed charge")
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
        item.startDate = startDate
        if isActive {
            item.endDate = nil
        } else if item.endDate == nil {
            item.endDate = .now
        }
        if charge == nil { context.insert(item) }
        dismiss()
    }
}

import SwiftData
import SwiftUI

/// Monthly income minus recurring charges: what's left each month,
/// shown as a jar that fills up.
struct MonthlyView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FixedCharge.dayOfMonth) private var charges: [FixedCharge]
    @Query(sort: \Investment.name) private var investments: [Investment]
    @AppStorage(AppSettings.incomeKey) private var income: Double = 0
    @Binding var showingSettings: Bool
    @State private var adding = false
    @State private var editing: FixedCharge?
    @State private var editingPlan = false

    private var total: Double { charges.reduce(0) { $0 + $1.amount } }
    private var savers: [Investment] { investments.filter { $0.monthlyContribution > 0 } }
    private var savings: Double { savers.reduce(0) { $0 + $1.monthlyContribution } }
    /// What's really free to spend: income minus charges and planned savings.
    private var left: Double { income - total - savings }
    private var level: Double { income > 0 ? max(left, 0) / income : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    incomeCard
                    SectionTitle(title: "Recurring charges", trailing: total.currency)
                    if charges.isEmpty {
                        emptyState
                    }
                    ForEach(charges) { charge in
                        Button { editing = charge } label: { ChargeCard(charge: charge) }
                            .buttonStyle(SquishyButtonStyle())
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = charge }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    withAnimation(.snappy) { context.delete(charge) }
                                }
                            }
                            .transition(.opacity)
                    }
                    savingsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .animation(.snappy, value: charges.count)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("This month")
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
            .sheet(isPresented: $editingPlan) { SavingsPlanView() }
            .sensoryFeedback(.success, trigger: charges.count) { old, new in new > old }
            .sensoryFeedback(.impact(weight: .light), trigger: charges.count) { old, new in new < old }
        }
    }

    // MARK: - Header with the jar

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                JarView(level: level)
                    .frame(width: 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text(left >= 0 ? (savings > 0 ? "Left after savings" : "Left this month") : "Over budget")
                        .font(.subheadline)
                        .foregroundStyle(Theme.softInk)
                    Text(abs(left).currency)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(left >= 0 ? Theme.ink : Theme.negative)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: left))
                        .animation(.snappy, value: left)
                    Text(income > 0 ? "of \(income.currency) income" : "Enter your monthly income below.")
                        .font(.footnote)
                        .foregroundStyle(Theme.softInk)
                }
            }
            if income > 0 || total > 0 {
                IncomeBar(income: income, charges: total, savings: savings)
            }
        }
        .card()
    }

    private var incomeCard: some View {
        HStack {
            Text("Monthly income")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Spacer()
            TextField("0", value: $income, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: 140)
                .accessibilityIdentifier("monthly-income")
        }
        .card()
    }

    @ViewBuilder
    private var savingsSection: some View {
        SectionTitle(title: "Monthly savings", trailing: savings > 0 ? savings.currency : nil)
        ForEach(savers) { investment in
            Button { editingPlan = true } label: {
                HStack(spacing: 12) {
                    EmojiBubble(emoji: investment.displayEmoji, color: investment.kind.color)
                    Text(investment.name)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(investment.monthlyContribution.currency)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                }
                .card(padding: 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(SquishyButtonStyle())
        }
        if savers.isEmpty {
            VStack(spacing: 8) {
                Text("No savings plan yet")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Set how much goes to each investment every month, e.g. 200 € to a savings account and 300 € to gold.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.softInk)
                Button("Plan monthly savings") { editingPlan = true }
                    .buttonStyle(PillButtonStyle())
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .card()
        } else {
            Button("Edit savings plan", systemImage: "slider.horizontal.3") { editingPlan = true }
                .buttonStyle(PillButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No recurring charges yet")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Add rent, subscriptions, insurance and anything else paid every month.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.softInk)
            Button("Add a charge") { adding = true }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

private struct ChargeCard: View {
    let charge: FixedCharge

    var body: some View {
        HStack(spacing: 12) {
            EmojiBubble(emoji: charge.displayEmoji, color: charge.category.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(charge.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Day \(charge.dayOfMonth) · \(charge.category.label)")
                    .font(.caption)
                    .foregroundStyle(Theme.softInk)
            }
            Spacer()
            Text(charge.amount.currency)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .card(padding: 12)
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
    @State private var emoji: String

    init(charge: FixedCharge? = nil) {
        self.charge = charge
        _title = State(initialValue: charge?.title ?? "")
        _amount = State(initialValue: charge?.amount)
        _category = State(initialValue: charge?.category ?? .housing)
        _dayOfMonth = State(initialValue: charge?.dayOfMonth ?? 1)
        _emoji = State(initialValue: charge?.displayEmoji ?? ChargeCategory.housing.emoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        EmojiBubble(emoji: emoji.isEmpty ? category.emoji : emoji, color: category.color, size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Title (e.g. Rent)", text: $title)
                        .accessibilityIdentifier("charge-title")
                    NumberField(title: "Amount", value: $amount, identifier: "charge-amount")
                    Picker("Category", selection: $category) {
                        ForEach(ChargeCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    Stepper("Day of month: \(dayOfMonth)", value: $dayOfMonth, in: 1...31)
                }
                Section("Icon") {
                    EmojiPicker(emoji: $emoji, suggestions: EmojiPicker.charges)
                }
                if let charge {
                    Section {
                        Button("Delete this charge", role: .destructive) {
                            context.delete(charge)
                            dismiss()
                        }
                    }
                }
            }
            .themedForm()
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
            .onChange(of: category) { old, new in
                // Follow the category until a custom emoji is picked
                if emoji == old.emoji { emoji = new.emoji }
            }
        }
    }

    private func save() {
        let item = charge ?? FixedCharge(title: "", amount: 0)
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.amount = amount ?? 0
        item.category = category
        item.dayOfMonth = dayOfMonth
        item.emoji = emoji == category.emoji ? "" : emoji
        if charge == nil { context.insert(item) }
        dismiss()
    }
}

import SwiftData
import SwiftUI

/// Everything that comes in each month: the main income, other income
/// that can be switched on and off, and money lent being paid back.
struct IncomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \Lending.date) private var lendings: [Lending]
    @AppStorage(AppSettings.incomeKey) private var income: Double = 0
    @Binding var showingSnapshot: Bool
    @State private var addingSource = false
    @State private var addingLending = false
    @State private var editing: IncomeSource?

    private var totals: IncomeTotals { IncomeTotals(main: income, sources: sources, lendings: lendings) }
    private var owed: Double { lendings.reduce(0) { $0 + $1.remaining } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    mainIncomeCard
                    otherIncomeSection
                    lendingSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .animation(.snappy, value: sources.count + lendings.count)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("Income")
            .navigationDestination(for: Lending.self) { LendingDetailView(lending: $0) }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    SnapshotButton(isPresented: $showingSnapshot)
                    Menu {
                        Button("Add income", systemImage: "plus.circle") { addingSource = true }
                        Button("Add money lent", systemImage: "arrow.up.right.circle") { addingLending = true }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $addingSource) { IncomeSourceFormView() }
            .sheet(isPresented: $addingLending) { LendingFormView() }
            .sheet(item: $editing) { IncomeSourceFormView(source: $0) }
            .sensoryFeedback(.success, trigger: sources.count + lendings.count) { old, new in new > old }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly income")
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
                Text(totals.total.currency)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: totals.total))
                    .animation(.snappy, value: totals.total)
            }
            if totals.other > 0 || totals.repayments > 0 {
                HStack(spacing: 6) {
                    Chip(text: "Main \(totals.main.currency)")
                    if totals.other > 0 { Chip(text: "Other \(totals.other.currency)") }
                    if totals.repayments > 0 { Chip(text: "Repaid to you \(totals.repayments.currency)") }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var mainIncomeCard: some View {
        HStack {
            Text("Main income")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Spacer()
            DecimalField(value: Binding(
                get: { income > 0 ? income : nil },
                set: { income = max($0 ?? 0, 0) }
            ))
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
    private var otherIncomeSection: some View {
        SectionTitle(title: "Other income", trailing: totals.other > 0 ? totals.other.currency : nil)
        if sources.isEmpty {
            hint(
                title: "No other income yet",
                text: "Add income that comes in some months only, like freelance work or a bonus, and switch it on when it does.",
                button: "Add income"
            ) { addingSource = true }
        }
        ForEach(sources) { source in
            IncomeSourceCard(source: source) { editing = source }
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { editing = source }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        withAnimation(.snappy) { context.delete(source) }
                    }
                }
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var lendingSection: some View {
        SectionTitle(title: "Money lent", trailing: owed > 0 ? "\(owed.currency) owed" : nil)
        if lendings.isEmpty {
            hint(
                title: "No money lent",
                text: "Lent money to someone? Follow what they pay back. A monthly repayment counts as income until it's all repaid.",
                button: "Add money lent"
            ) { addingLending = true }
        }
        ForEach(lendings) { lending in
            NavigationLink(value: lending) { LendingCard(lending: lending) }
                .buttonStyle(SquishyButtonStyle())
                .transition(.opacity)
        }
    }

    private func hint(title: String, text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.softInk)
            Button(button, action: action)
                .buttonStyle(PillButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

/// An income line with a switch: off when it doesn't come in this month.
private struct IncomeSourceCard: View {
    @Bindable var source: IncomeSource
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 12) {
                    EmojiBubble(emoji: source.emoji, color: Theme.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text(source.isActive ? "Counted this month" : "Not this month")
                            .font(.caption)
                            .foregroundStyle(Theme.softInk)
                    }
                    Spacer()
                    Text(source.amount.currency)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(source.isActive ? Theme.ink : Theme.softInk)
                        .strikethrough(!source.isActive)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SquishyButtonStyle())
            Toggle(source.title, isOn: $source.isActive.animation(.snappy))
                .labelsHidden()
                .tint(Theme.accent)
                .accessibilityIdentifier("income-toggle-\(source.title)")
        }
        .opacity(source.isActive ? 1 : 0.7)
        .card(padding: 12)
    }
}

struct IncomeSourceFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let source: IncomeSource?

    @State private var title: String
    @State private var amount: Double?
    @State private var emoji: String
    @State private var isActive: Bool

    init(source: IncomeSource? = nil) {
        self.source = source
        _title = State(initialValue: source?.title ?? "")
        _amount = State(initialValue: source?.amount)
        _emoji = State(initialValue: source?.emoji ?? "💼")
        _isActive = State(initialValue: source?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        EmojiBubble(emoji: emoji.isEmpty ? "💼" : emoji, color: Theme.mint, size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Title (e.g. Freelance)", text: $title)
                        .accessibilityIdentifier("income-title")
                    NumberField(title: "Amount per month", value: $amount, identifier: "income-amount")
                    Toggle("Counted this month", isOn: $isActive)
                        .tint(Theme.accent)
                } footer: {
                    Text("Switch it off in the months it doesn't come in: it stays listed but isn't counted.")
                }
                Section("Icon") {
                    EmojiPicker(emoji: $emoji, suggestions: EmojiPicker.income)
                }
                if let source {
                    Section {
                        Button("Delete this income", role: .destructive) {
                            context.delete(source)
                            dismiss()
                        }
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(source == nil ? "New income" : "Edit income")
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
        let item = source ?? IncomeSource(title: "", amount: 0)
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.amount = amount ?? 0
        item.emoji = emoji.isEmpty ? "💼" : emoji
        item.isActive = isActive
        if source == nil { context.insert(item) }
        dismiss()
    }
}

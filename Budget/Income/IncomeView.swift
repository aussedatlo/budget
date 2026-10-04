import SwiftData
import SwiftUI

/// Everything that comes in each month: income lines that can be switched
/// on and off, and money lent being paid back.
struct IncomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \Lending.date) private var lendings: [Lending]
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]
    @Binding var showingSnapshot: Bool
    @State private var addingSource = false
    @State private var addingLending = false
    @State private var editing: IncomeSource?
    @State private var deleting: IncomeSource?
    @State private var showingRepaid = false
    /// Goes up with the monthly income: a coin drops into the piggy bank.
    @State private var coinDrops = 0

    private var totals: IncomeTotals { IncomeTotals(sources: sources, lendings: lendings) }
    private var owed: Double { lendings.reduce(0) { $0 + $1.remaining } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    incomeSection
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
            .confirmDelete($deleting, title: { "Delete \($0.title)?" }) { source in
                withAnimation(.snappy) { context.delete(source) }
            }
            .sensoryFeedback(.success, trigger: sources.count + lendings.count) { old, new in new > old }
            .onChange(of: totals.total) { old, new in
                if new > old + 0.01 { coinDrops += 1 }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 18) {
                PiggyBankView(coins: coinDrops)
                    .frame(width: 100)
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
            }
            if totals.repayments > 0 {
                FlowChips {
                    Chip(text: "Income \(totals.sources.currency)")
                    Chip(text: "Repaid to you \(totals.repayments.currency)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private var incomeSection: some View {
        SectionTitle(title: "Income", trailing: totals.sources > 0 ? totals.sources.currency : nil)
        if sources.isEmpty {
            hint(
                title: "No income yet",
                text: "Add your salary and any other income, like freelance work or a bonus. Switch a line off in the months it doesn't come in.",
                button: "Add income"
            ) { addingSource = true }
        }
        ForEach(sources) { source in
            IncomeSourceCard(source: source, lastCounted: lastCounted(source)) { editing = source }
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { editing = source }
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = source }
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
        ForEach(lendings.filter { !$0.isSettled }) { lending in
            NavigationLink(value: lending) { LendingCard(lending: lending) }
                .buttonStyle(SquishyButtonStyle())
                .transition(.opacity)
        }
        let repaid = lendings.filter(\.isSettled)
        if !repaid.isEmpty {
            Button {
                withAnimation(.snappy) { showingRepaid.toggle() }
            } label: {
                HStack {
                    Text("Fully repaid (\(repaid.count))")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(showingRepaid ? 0 : -90))
                }
                .font(.subheadline.bold())
                .foregroundStyle(Theme.softInk)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showingRepaid {
                ForEach(repaid) { lending in
                    NavigationLink(value: lending) { LendingCard(lending: lending) }
                        .buttonStyle(SquishyButtonStyle())
                        .transition(.opacity)
                }
            }
        }
    }

    /// The month of the latest snapshot that counted this income, when it's
    /// not the current month: a hint to switch it on or off for the new month.
    private func lastCounted(_ source: IncomeSource) -> Date? {
        let snapshot = snapshots.first { snapshot in
            snapshot.incomeLines.contains { $0.title == source.title }
        }
        guard let date = snapshot?.date, !Calendar.current.isDate(date, inSameMonthAs: .now) else { return nil }
        return date
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

/// An income line: tap it to edit it, or to switch it off in the months it
/// doesn't come in.
private struct IncomeSourceCard: View {
    let source: IncomeSource
    /// Month of the last snapshot it was counted in, if before this month.
    let lastCounted: Date?
    let edit: () -> Void

    private var subtitle: String {
        var text = source.isActive ? "Counted this month" : "Not this month"
        if let lastCounted { text += " · last counted in \(lastCounted.monthName)" }
        return text
    }

    var body: some View {
        Button(action: edit) {
            HStack(spacing: 12) {
                EmojiBubble(emoji: source.emoji, color: Theme.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.softInk)
                        .accessibilityIdentifier("income-status-\(source.title)")
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
    @State private var confirmingDelete = false

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
                        Button("Delete this income", role: .destructive) { confirmingDelete = true }
                            .confirmDelete("Delete \(source.title)?", isPresented: $confirmingDelete) {
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

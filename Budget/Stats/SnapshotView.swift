import SwiftData
import SwiftUI

/// Toolbar button that opens the snapshot of everything, on every tab.
struct SnapshotButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button { isPresented = true } label: {
            Label("Snapshot", systemImage: "camera")
        }
    }
}

/// Snapshot of everything at once: income, recurring charges, investments,
/// the home loan and money lent. Everything is pre-filled with the current
/// values, to check them and fix what moved before saving.
struct SnapshotView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FixedCharge.dayOfMonth) private var charges: [FixedCharge]
    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \Investment.name) private var investments: [Investment]
    @Query(sort: \Loan.name) private var loans: [Loan]
    @Query(sort: \Lending.date) private var allLendings: [Lending]
    @Query(sort: \Snapshot.date) private var snapshots: [Snapshot]
    @AppStorage(AppSettings.incomeKey) private var storedIncome: Double = 0

    private struct SourceDraft {
        var amount: Double?
        var isActive: Bool
    }

    @State private var date = Date.now
    @State private var note = ""
    @State private var mainIncome: Double?
    @State private var sourceDrafts: [PersistentIdentifier: SourceDraft] = [:]
    @State private var chargeDrafts: [PersistentIdentifier: Double?] = [:]
    @State private var drafts: [PersistentIdentifier: SnapshotDraft] = [:]
    @State private var loanDrafts: [PersistentIdentifier: LoanDraft] = [:]
    @State private var lendingDrafts: [PersistentIdentifier: Double?] = [:]

    init() {
        let income = UserDefaults.standard.double(forKey: AppSettings.incomeKey)
        _mainIncome = State(initialValue: income > 0 ? income : nil)
    }

    /// Money lent that isn't fully repaid yet.
    private var lendings: [Lending] { allLendings.filter { !$0.isSettled } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        StatTile(title: left >= 0 ? "Left each month" : "Over budget",
                                 value: abs(left).currency, color: left >= 0 ? Theme.ink : Theme.negative)
                        StatTile(title: "Net worth", value: netWorth.currency)
                    }
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    TextField("Note", text: $note)
                } footer: {
                    Text(summaryFooter)
                }
                incomeSection
                chargesSection
                ForEach(investments) { investment in
                    Section {
                        SnapshotFields(draft: draftBinding(for: investment), showsDate: false, showsUnitsToggle: false)
                    } header: {
                        itemHeader(investment.displayEmoji, investment.name)
                    }
                }
                ForEach(loans) { loan in
                    Section {
                        LoanFields(draft: loanBinding(for: loan))
                    } header: {
                        itemHeader(loan.emoji, loan.name)
                    }
                }
                ForEach(lendings) { lending in
                    Section {
                        NumberField(title: "Left to repay", value: lendingBinding(for: lending))
                    } header: {
                        itemHeader(lending.emoji, "Lent to \(lending.name)")
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: date) {
                for investment in investments {
                    var updated = investmentDraft(of: investment)
                    updated.date = date
                    updated.applyPlan()
                    drafts[investment.persistentModelID] = updated
                }
            }
            .navigationTitle("Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    // MARK: - Sections

    private var incomeSection: some View {
        Section {
            NumberField(title: "Main income", value: $mainIncome, identifier: "snapshot-main-income")
            ForEach(sources) { source in
                let draft = sourceBinding(for: source)
                HStack(spacing: 10) {
                    Toggle(source.title, isOn: draft.isActive)
                        .labelsHidden()
                        .tint(Theme.accent)
                        .accessibilityIdentifier("snapshot-income-toggle-\(source.title)")
                    Text(source.title)
                        .foregroundStyle(draft.wrappedValue.isActive ? Theme.ink : Theme.softInk)
                    Spacer()
                    DecimalField(value: draft.amount)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                        .accessibilityIdentifier("snapshot-income-\(source.title)")
                }
            }
            if repayments > 0 {
                LabeledContent("Repaid to you", value: repayments.currency)
            }
        } header: {
            totalHeader("Income", income)
        }
    }

    @ViewBuilder
    private var chargesSection: some View {
        if !charges.isEmpty {
            Section {
                ForEach(charges) { charge in
                    HStack(spacing: 10) {
                        Moji(charge.displayEmoji, size: 22)
                        NumberField(title: charge.title, value: chargeBinding(for: charge),
                                    identifier: "snapshot-charge-\(charge.title)")
                    }
                }
                if savings > 0 {
                    LabeledContent("Monthly savings", value: savings.currency)
                }
            } header: {
                totalHeader("Recurring charges", chargesTotal)
            }
        }
    }

    private func totalHeader(_ title: String, _ total: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(total.currency).monospacedDigit()
        }
    }

    private func itemHeader(_ emoji: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            Moji(emoji, size: 18)
            Text(title)
        }
    }

    private var summaryFooter: String {
        var text = "Everything is pre-filled with your current values. Check them, fix what moved, then save."
        if snapshots.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            text += " This replaces the snapshot already taken that day."
        }
        if let previous {
            let before = Wealth.point(at: Calendar.current.endOfDay(for: previous.date),
                                      investments: investments, loans: loans, lendings: allLendings)
            let day = previous.date.formatted(date: .abbreviated, time: .omitted)
            text += "\n\nSince \(day): net worth \((netWorth - before.netWorth).signedCurrency), left each month \((left - previous.left).signedCurrency)."
        }
        return text
    }

    /// The latest snapshot taken before the day of this one.
    private var previous: Snapshot? {
        let day = Calendar.current.startOfDay(for: date)
        return snapshots.last { $0.date < day }
    }

    // MARK: - Drafts

    private func sourceDraft(of source: IncomeSource) -> SourceDraft {
        sourceDrafts[source.persistentModelID] ?? SourceDraft(amount: source.amount, isActive: source.isActive)
    }

    private func chargeAmount(of charge: FixedCharge) -> Double? {
        chargeDrafts[charge.persistentModelID] ?? Optional(charge.amount)
    }

    private func investmentDraft(of investment: Investment) -> SnapshotDraft {
        drafts[investment.persistentModelID]
            ?? SnapshotDraft(from: investment.latest, monthlyContribution: investment.monthlyContribution)
    }

    private func loanDraft(of loan: Loan) -> LoanDraft {
        loanDrafts[loan.persistentModelID] ?? LoanDraft(from: loan.latest, loan: loan)
    }

    private func lendingRemaining(of lending: Lending) -> Double? {
        lendingDrafts[lending.persistentModelID] ?? Optional(lending.remaining)
    }

    private func sourceBinding(for source: IncomeSource) -> Binding<SourceDraft> {
        Binding(
            get: { sourceDraft(of: source) },
            set: { sourceDrafts[source.persistentModelID] = $0 }
        )
    }

    private func chargeBinding(for charge: FixedCharge) -> Binding<Double?> {
        Binding(
            get: { chargeAmount(of: charge) },
            set: { chargeDrafts[charge.persistentModelID] = .some($0) }
        )
    }

    private func draftBinding(for investment: Investment) -> Binding<SnapshotDraft> {
        Binding(
            get: { investmentDraft(of: investment) },
            set: { drafts[investment.persistentModelID] = $0 }
        )
    }

    private func loanBinding(for loan: Loan) -> Binding<LoanDraft> {
        Binding(
            get: { loanDraft(of: loan) },
            set: { loanDrafts[loan.persistentModelID] = $0 }
        )
    }

    private func lendingBinding(for lending: Lending) -> Binding<Double?> {
        Binding(
            get: { lendingRemaining(of: lending) },
            set: { lendingDrafts[lending.persistentModelID] = .some($0) }
        )
    }

    // MARK: - Totals as they would be saved

    private var otherIncome: Double {
        var total = 0.0
        for source in sources {
            let draft = sourceDraft(of: source)
            if draft.isActive { total += max(draft.amount ?? 0, 0) }
        }
        return total
    }

    private var repayments: Double {
        var total = 0.0
        for lending in lendings {
            let owed = max(lendingRemaining(of: lending) ?? lending.remaining, 0)
            total += min(lending.monthlyRepayment, owed)
        }
        return total
    }

    private var income: Double { max(mainIncome ?? 0, 0) + otherIncome + repayments }

    private var chargesTotal: Double {
        var total = 0.0
        for charge in charges { total += chargeAmount(of: charge) ?? 0 }
        return total
    }

    private var savings: Double { investments.reduce(0) { $0 + $1.monthlyContribution } }
    private var left: Double { income - chargesTotal - savings }

    private var netWorth: Double {
        var total = 0.0
        for investment in investments { total += investmentDraft(of: investment).computedValue }
        for loan in loans {
            let draft = loanDraft(of: loan)
            total += (draft.homeValue ?? 0) - (draft.remaining ?? 0)
        }
        for lending in lendings { total += max(lendingRemaining(of: lending) ?? lending.remaining, 0) }
        return total
    }

    // MARK: - Save

    private func save() {
        // The budget: what was corrected here becomes the current state
        storedIncome = max(mainIncome ?? 0, 0)
        for source in sources {
            let draft = sourceDraft(of: source)
            if let amount = draft.amount { source.amount = max(amount, 0) }
            source.isActive = draft.isActive
        }
        for charge in charges {
            if let amount = chargeAmount(of: charge) { charge.amount = max(amount, 0) }
        }

        // Values of the day, replacing the ones already recorded that day
        for lending in lendings {
            guard let owed = lendingRemaining(of: lending) else { continue }
            let existing = lending.entry(on: date)
            let entry = existing ?? LendingSnapshot()
            entry.date = date
            entry.remaining = max(owed, 0)
            if existing == nil {
                context.insert(entry)
                lending.history.append(entry)
            }
        }
        for investment in investments {
            var draft = investmentDraft(of: investment)
            guard draft.isValid else { continue }
            let existing = investment.entry(on: date)
            draft.date = date
            draft.note = existing?.note ?? ""
            let entry = existing ?? ValueSnapshot()
            draft.apply(to: entry)
            if existing == nil {
                context.insert(entry)
                investment.history.append(entry)
            }
        }
        for loan in loans {
            var draft = loanDraft(of: loan)
            guard draft.isValid else { continue }
            let existing = loan.entry(on: date)
            draft.date = date
            draft.note = existing?.note ?? ""
            let entry = existing ?? LoanSnapshot()
            draft.apply(to: entry)
            if existing == nil {
                context.insert(entry)
                loan.history.append(entry)
            }
        }

        let taken = snapshots.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let snapshot = taken ?? Snapshot()
        snapshot.date = date
        snapshot.note = note
        snapshot.capture(mainIncome: max(mainIncome ?? 0, 0), sources: sources, lendings: allLendings,
                         charges: charges, investments: investments)
        if taken == nil { context.insert(snapshot) }
        dismiss()
    }
}

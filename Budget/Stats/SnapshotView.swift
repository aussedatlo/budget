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

/// The month's snapshot of everything at once: income, recurring charges,
/// investments, the home loan and money lent. Everything is pre-filled with
/// the current values, to check them and fix what moved before saving.
/// When months were skipped since the last snapshot, it asks which one to do.
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

    private let currentMonth = Calendar.current.monthInterval(for: .now).start
    /// First day of the month this snapshot is for.
    @State private var month = Calendar.current.monthInterval(for: .now).start
    @State private var askingMonth = false
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

    private var isCurrentMonth: Bool { month == currentMonth }
    /// The current month is dated now; a month caught up later, on its last day.
    private var date: Date { isCurrentMonth ? .now : Calendar.current.endOfMonth(for: month) }

    /// Months without a snapshot between the last one and the current month.
    private var missing: [Date] {
        guard let last = snapshots.last else { return [] }
        let calendar = Calendar.current
        var months: [Date] = []
        var next = calendar.date(byAdding: .month, value: 1, to: last.month)!
        while next < currentMonth {
            months.append(next)
            next = calendar.date(byAdding: .month, value: 1, to: next)!
        }
        return Array(months.suffix(12))
    }

    /// The snapshot already taken for this month, replaced on save.
    private var taken: Snapshot? {
        snapshots.first { Calendar.current.isDate($0.date, inSameMonthAs: month) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        StatTile(title: left >= 0 ? "Left each month" : "Over budget",
                                 value: abs(left).currency, color: left >= 0 ? Theme.ink : Theme.negative)
                        StatTile(title: "Net worth", value: netWorth.currency)
                    }
                    if missing.isEmpty {
                        LabeledContent("Month", value: month.monthName)
                    } else {
                        Picker("Month", selection: $month) {
                            ForEach(missing + [currentMonth], id: \.self) { month in
                                Text(month.monthName).tag(month)
                            }
                        }
                    }
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
            .onAppear {
                if !missing.isEmpty { askingMonth = true }
            }
            .alert(missedTitle, isPresented: $askingMonth) {
                ForEach(missing.suffix(3), id: \.self) { missed in
                    Button(missed.monthName) { month = missed }
                }
                Button(currentMonth.monthName) { month = currentMonth }
            } message: {
                Text("Catch up on a missing month, or go for \(currentMonth.monthName)? You can change it at the top of the snapshot.")
            }
            .onChange(of: month) {
                let date = self.date
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

    private var missedTitle: String {
        let missing = self.missing
        if missing.count == 1, let missed = missing.first { return "No snapshot for \(missed.monthName)" }
        return "No snapshot for \(missing.count) months"
    }

    private var summaryFooter: String {
        var text = "Everything is pre-filled with your current values. Check them, fix what moved, then save."
        if !isCurrentMonth {
            text += " Income and charges changed here are saved in this past month only: the tabs keep your current state."
        }
        if taken != nil {
            text += " This replaces the snapshot already taken for \(month.monthName)."
        }
        if let previous {
            let before = Wealth.point(at: previous.endOfMonth,
                                      investments: investments, loans: loans, lendings: allLendings)
            let day = previous.date.monthName
            text += "\n\nSince \(day): net worth \((netWorth - before.netWorth).signedCurrency), left each month \((left - previous.left).signedCurrency)."
        }
        return text
    }

    /// The latest snapshot of an earlier month.
    private var previous: Snapshot? {
        snapshots.last { $0.date < month }
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
            if draft.isActive { total += max(draft.amount ?? source.amount, 0) }
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
        for charge in charges { total += max(chargeAmount(of: charge) ?? charge.amount, 0) }
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
        let date = self.date

        // The budget of the month. Fixed for the current month, it becomes
        // the current state; a past month keeps it to itself.
        let main = max(mainIncome ?? 0, 0)
        var incomeLines = [SnapshotLine(title: "Main income", amount: main)]
        var other = 0.0
        for source in sources {
            let draft = sourceDraft(of: source)
            let amount = max(draft.amount ?? source.amount, 0)
            if draft.isActive {
                other += amount
                incomeLines.append(SnapshotLine(title: source.title, amount: amount))
            }
            if isCurrentMonth {
                source.amount = amount
                source.isActive = draft.isActive
            }
        }
        var repaid = 0.0
        for lending in lendings {
            let owed = max(lendingRemaining(of: lending) ?? lending.remaining, 0)
            let amount = min(lending.monthlyRepayment, owed)
            guard amount > 0 else { continue }
            repaid += amount
            incomeLines.append(SnapshotLine(title: "Repaid by \(lending.name)", amount: amount))
        }
        var chargeLines: [SnapshotLine] = []
        for charge in charges {
            let amount = max(chargeAmount(of: charge) ?? charge.amount, 0)
            chargeLines.append(SnapshotLine(title: charge.title, amount: amount, category: charge.categoryRaw))
            if isCurrentMonth { charge.amount = amount }
        }
        if isCurrentMonth { storedIncome = main }

        // Values of the month, replacing the ones already recorded that month
        for lending in lendings {
            guard let owed = lendingRemaining(of: lending) else { continue }
            let existing = lending.entry(inMonthOf: date)
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
            let existing = investment.entry(inMonthOf: date)
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
            let existing = loan.entry(inMonthOf: date)
            draft.date = date
            draft.note = existing?.note ?? ""
            let entry = existing ?? LoanSnapshot()
            draft.apply(to: entry)
            if existing == nil {
                context.insert(entry)
                loan.history.append(entry)
            }
        }

        let existing = taken
        let snapshot = existing ?? Snapshot()
        snapshot.date = date
        snapshot.note = note
        snapshot.mainIncome = main
        snapshot.otherIncome = other
        snapshot.repayments = repaid
        snapshot.charges = chargeLines.reduce(0) { $0 + $1.amount }
        snapshot.savings = savings
        snapshot.incomeLines = incomeLines
        snapshot.chargeLines = chargeLines
        if existing == nil { context.insert(snapshot) }
        dismiss()
    }
}

import SwiftData
import SwiftUI

/// Toolbar button that opens the snapshot of everything, on every tab.
/// Its icon shows whether this month's snapshot is still to take.
struct SnapshotButton: View {
    @Binding var isPresented: Bool
    @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

    var body: some View {
        let isDone = Snapshot.isTaken(thisMonthIn: snapshots)
        Button { isPresented = true } label: {
            Label("Snapshot", systemImage: isDone ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark")
        }
        .accessibilityValue(isDone ? "Taken this month" : "To take this month")
    }
}

/// The month's snapshot of everything at once: income, recurring charges,
/// investments and the home loan. Everything is pre-filled with
/// the current values, to check them and fix what moved before saving.
/// When months were skipped since the last snapshot, it asks which one to do.
/// Money lent is kept up to date on the Income tab: only its repayments show here.
struct SnapshotView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FixedCharge.amount, order: .reverse) private var charges: [FixedCharge]
    @Query(sort: \IncomeSource.createdAt) private var sources: [IncomeSource]
    @Query(sort: \Investment.name) private var investments: [Investment]
    @Query(sort: \Loan.name) private var loans: [Loan]
    @Query(sort: \Lending.date) private var allLendings: [Lending]
    @Query(sort: \Snapshot.date) private var snapshots: [Snapshot]

    private struct SourceDraft {
        var amount: Double?
        var isActive: Bool
    }

    private let currentMonth = Calendar.current.monthInterval(for: .now).start
    /// First day of the month this snapshot is for.
    @State private var month = Calendar.current.monthInterval(for: .now).start
    @State private var askingMonth = false
    @State private var confirmingDiscard = false
    @State private var note = ""
    @State private var sourceDrafts: [PersistentIdentifier: SourceDraft] = [:]
    @State private var chargeDrafts: [PersistentIdentifier: Double?] = [:]
    @State private var drafts: [PersistentIdentifier: SnapshotDraft] = [:]
    @State private var loanDrafts: [PersistentIdentifier: LoanDraft] = [:]
    /// Repayments and planned savings switched off for this snapshot only.
    @State private var skippedRepayments: Set<PersistentIdentifier> = []
    @State private var skippedSavings: Set<PersistentIdentifier> = []

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
                    if let taken {
                        Label("Replaces the snapshot taken on \(taken.date.formatted(date: .abbreviated, time: .omitted))",
                              systemImage: "arrow.triangle.2.circlepath")
                            .font(.footnote)
                            .foregroundStyle(Theme.accent)
                    }
                    TextField("Note", text: $note)
                } footer: {
                    Text(summaryFooter)
                }
                incomeSection
                savingsSection
                chargesSection
                ForEach(investments) { investment in
                    Section {
                        SnapshotFields(draft: draftBinding(for: investment), showsDate: false, showsUnitsToggle: false,
                                       showsInvested: false)
                    } header: {
                        itemHeader(investment.displayEmoji, investment.name, edited: isEdited(investment))
                    } footer: {
                        if let latest = investment.latest {
                            lastRecorded(latest.value.currency, on: latest.date)
                        }
                    }
                }
                ForEach(loans) { loan in
                    Section {
                        LoanFields(draft: loanBinding(for: loan))
                    } header: {
                        itemHeader(loan.emoji, loan.name, edited: isEdited(loan))
                    } footer: {
                        if let latest = loan.latest {
                            lastRecorded("\(latest.remaining.currency) left to repay, home \(latest.homeValue.currency)",
                                         on: latest.date)
                        }
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog("Discard your changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("Nothing in this snapshot is saved yet.")
            }
            .onAppear {
                if !missing.isEmpty { askingMonth = true }
            }
            .alert(missedTitle, isPresented: $askingMonth) {
                ForEach(missing.suffix(3), id: \.self) { missed in
                    Button(missed.monthName) { month = missed }
                }
                Button(currentMonth.monthName) { month = currentMonth }
            } message: {
                Text(missedMessage)
            }
            .navigationTitle("Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { confirmingDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    // MARK: - Sections

    private var incomeSection: some View {
        Section {
            if sources.isEmpty {
                Text("No income yet: add it in the Income tab.")
                    .foregroundStyle(Theme.softInk)
            }
            ForEach(sources) { source in
                let draft = sourceBinding(for: source)
                HStack(spacing: 10) {
                    Toggle(source.title, isOn: draft.isActive)
                        .labelsHidden()
                        .tint(Theme.accent)
                        .accessibilityIdentifier("snapshot-income-toggle-\(source.title)")
                    Text(source.title)
                        .foregroundStyle(isEdited(source) ? Theme.accent
                                         : draft.wrappedValue.isActive ? Theme.ink : Theme.softInk)
                    Spacer()
                    DecimalField(value: draft.amount)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                        .accessibilityIdentifier("snapshot-income-\(source.title)")
                }
            }
            ForEach(lendings.filter { repayment(of: $0) > 0 }) { lending in
                switchRow("Repaid by \(lending.name)", amount: repayment(of: lending),
                          isOn: inclusion(of: lending.persistentModelID, in: $skippedRepayments),
                          identifier: "snapshot-repayment-toggle-\(lending.name)")
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
                            .foregroundStyle(isEdited(charge) ? Theme.accent : Theme.ink)
                    }
                }
            } header: {
                totalHeader("Recurring charges", chargesTotal)
            }
        }
    }

    @ViewBuilder
    private var savingsSection: some View {
        let planned = investments.filter { $0.monthlyContribution > 0 }
        if !planned.isEmpty {
            Section {
                ForEach(planned) { investment in
                    switchRow(investment.name, amount: investment.monthlyContribution,
                              isOn: inclusion(of: investment.persistentModelID, in: $skippedSavings),
                              identifier: "snapshot-saving-toggle-\(investment.name)")
                }
            } header: {
                totalHeader("Monthly savings", savings)
            } footer: {
                Text("Switch off what wasn't paid or saved this month. It only changes this snapshot.")
            }
        }
    }

    /// A repayment or a planned saving, counted in this snapshot or not.
    private func switchRow(_ title: String, amount: Double, isOn: Binding<Bool>, identifier: String) -> some View {
        HStack(spacing: 10) {
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(Theme.accent)
                .accessibilityIdentifier(identifier)
            Text(title)
                .foregroundStyle(isOn.wrappedValue ? Theme.ink : Theme.accent)
            Spacer()
            Text(amount.currency)
                .strikethrough(!isOn.wrappedValue)
                .foregroundStyle(Theme.softInk)
        }
    }

    /// On while `id` isn't in `skipped`.
    private func inclusion(of id: PersistentIdentifier, in skipped: Binding<Set<PersistentIdentifier>>) -> Binding<Bool> {
        Binding(
            get: { !skipped.wrappedValue.contains(id) },
            set: { isOn in
                if isOn { skipped.wrappedValue.remove(id) } else { skipped.wrappedValue.insert(id) }
            }
        )
    }

    private func totalHeader(_ title: String, _ total: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(total.currency).monospacedDigit()
        }
    }

    private func itemHeader(_ emoji: String, _ title: String, edited: Bool = false) -> some View {
        HStack(spacing: 6) {
            Moji(emoji, size: 18)
            Text(title)
            Spacer()
            if edited {
                Text("Edited").foregroundStyle(Theme.accent)
            }
        }
    }

    private func lastRecorded(_ value: String, on date: Date) -> some View {
        Text("Last recorded: \(value) on \(date.formatted(date: .abbreviated, time: .omitted))")
    }

    private var missedTitle: String {
        let missing = self.missing
        if missing.count == 1, let missed = missing.first { return "No snapshot for \(missed.monthName)" }
        return "No snapshot for \(missing.count) months"
    }

    private var missedMessage: String {
        var text = "Catch up on a missing month, or go for \(currentMonth.monthName)? You can change it at the top of the snapshot."
        if missing.count > 3 { text += " Older months are listed there too." }
        return text
    }

    private var summaryFooter: String {
        var text = "Everything is pre-filled with your current values. Check them, fix what moved, then save. What you changed shows in color."
        if !isCurrentMonth {
            text += " Investments and the home loan start from their latest values: set them to what they were in \(month.monthName)."
            text += " Income and charges changed here are saved in this past month only: the tabs keep your current state."
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
        drafts[investment.persistentModelID] ?? baseDraft(of: investment)
    }

    /// The latest values; "invested so far" is worked out when saving.
    private func baseDraft(of investment: Investment) -> SnapshotDraft {
        SnapshotDraft(from: investment.latest)
    }

    private func loanDraft(of loan: Loan) -> LoanDraft {
        loanDrafts[loan.persistentModelID] ?? LoanDraft(from: loan.latest, loan: loan)
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

    // MARK: - What was changed

    private func isEdited(_ investment: Investment) -> Bool {
        guard let draft = drafts[investment.persistentModelID] else { return false }
        return draft.differs(from: baseDraft(of: investment))
    }

    private func isEdited(_ loan: Loan) -> Bool {
        guard let draft = loanDrafts[loan.persistentModelID] else { return false }
        let base = LoanDraft(from: loan.latest, loan: loan)
        return draft.remaining.differs(from: base.remaining) || draft.homeValue.differs(from: base.homeValue)
    }

    private func isEdited(_ charge: FixedCharge) -> Bool {
        guard let amount = chargeDrafts[charge.persistentModelID] else { return false }
        return amount.differs(from: charge.amount)
    }

    private func isEdited(_ source: IncomeSource) -> Bool {
        guard let draft = sourceDrafts[source.persistentModelID] else { return false }
        return draft.isActive != source.isActive || draft.amount.differs(from: source.amount)
    }

    /// Something was changed and would be lost on Cancel.
    private var hasChanges: Bool {
        !note.isEmpty
            || !skippedRepayments.isEmpty
            || !skippedSavings.isEmpty
            || investments.contains { isEdited($0) }
            || loans.contains { isEdited($0) }
            || charges.contains { isEdited($0) }
            || sources.contains { isEdited($0) }
    }

    // MARK: - Totals as they would be saved

    private var sourcesIncome: Double {
        var total = 0.0
        for source in sources {
            let draft = sourceDraft(of: source)
            if draft.isActive { total += max(draft.amount ?? source.amount, 0) }
        }
        return total
    }

    /// What `lending` repays this month: never more than what is left.
    private func repayment(of lending: Lending) -> Double {
        min(lending.monthlyRepayment, lending.remaining)
    }

    private var repayments: Double {
        var total = 0.0
        for lending in lendings where !skippedRepayments.contains(lending.persistentModelID) {
            total += repayment(of: lending)
        }
        return total
    }

    private var income: Double { sourcesIncome + repayments }

    private var chargesTotal: Double {
        var total = 0.0
        for charge in charges { total += max(chargeAmount(of: charge) ?? charge.amount, 0) }
        return total
    }

    private var savings: Double {
        investments
            .filter { !skippedSavings.contains($0.persistentModelID) }
            .reduce(0) { $0 + $1.monthlyContribution }
    }
    private var left: Double { income - chargesTotal - savings }

    private var netWorth: Double {
        var total = 0.0
        for investment in investments { total += investmentDraft(of: investment).computedValue }
        for loan in loans {
            let draft = loanDraft(of: loan)
            total += (draft.homeValue ?? 0) - (draft.remaining ?? 0)
        }
        for lending in lendings { total += lending.remaining }
        return total
    }

    // MARK: - Save

    private func save() {
        let date = self.date

        // The budget of the month. Fixed for the current month, it becomes
        // the current state; a past month keeps it to itself.
        var incomeLines: [SnapshotLine] = []
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
        for lending in lendings where !skippedRepayments.contains(lending.persistentModelID) {
            let amount = repayment(of: lending)
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

        // Values of the month, replacing the ones already recorded that month
        for investment in investments {
            var draft = investmentDraft(of: investment)
            guard draft.isValid else { continue }
            let existing = investment.entry(inMonthOf: date)
            draft.date = date
            draft.note = existing?.note ?? ""
            draft.invested = investment.investedForSnapshot(
                at: date, savingIncluded: !skippedSavings.contains(investment.persistentModelID))
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
        // Income comes only from the income lines now; `mainIncome` is kept
        // for snapshots taken before.
        snapshot.mainIncome = 0
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

private extension Optional where Wrapped == Double {
    /// Different amounts, ignoring rounding from typing them.
    func differs(from other: Double?) -> Bool {
        switch (self, other) {
        case (nil, nil): return false
        case let (a?, b?): return abs(a - b) > 0.000_5
        default: return true
        }
    }
}

private extension SnapshotDraft {
    func differs(from other: SnapshotDraft) -> Bool {
        tracksUnits != other.tracksUnits
            || quantity.differs(from: other.quantity)
            || unitPrice.differs(from: other.unitPrice)
            || value.differs(from: other.value)
    }
}

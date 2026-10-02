import SwiftData
import SwiftUI

// MARK: - Snapshot draft

/// Editable copy of a snapshot. New snapshots start from the previous one,
/// so updating a position is just changing what moved.
struct SnapshotDraft {
    var date = Date.now
    var tracksUnits = false
    var quantity: Double?
    var unitPrice: Double?
    var value: Double?
    var invested: Double?
    var note = ""

    init() {}

    /// - Parameter keepDate: true to edit `snapshot`, false to start a new one from it.
    init(from snapshot: ValueSnapshot?, keepDate: Bool = false) {
        guard let snapshot else { return }
        date = keepDate ? snapshot.date : .now
        tracksUnits = snapshot.tracksUnits
        quantity = snapshot.quantity
        unitPrice = snapshot.unitPrice
        value = snapshot.value
        invested = snapshot.invested
        note = keepDate ? snapshot.note : ""
    }

    var computedValue: Double {
        tracksUnits ? (quantity ?? 0) * (unitPrice ?? 0) : (value ?? 0)
    }

    var isValid: Bool {
        tracksUnits ? (quantity != nil && unitPrice != nil) : value != nil
    }

    func apply(to snapshot: ValueSnapshot) {
        snapshot.date = date
        snapshot.value = computedValue
        snapshot.invested = invested ?? 0
        snapshot.quantity = tracksUnits ? quantity : nil
        snapshot.unitPrice = tracksUnits ? unitPrice : nil
        snapshot.note = note
    }
}

/// Form rows for a snapshot (inside a Form section).
struct SnapshotFields: View {
    @Binding var draft: SnapshotDraft
    var showsDate = true
    var showsUnitsToggle = true

    var body: some View {
        if showsDate {
            DatePicker("Date", selection: $draft.date, displayedComponents: .date)
        }
        if showsUnitsToggle {
            Toggle("Quantity × unit price", isOn: $draft.tracksUnits.animation(.bouncy))
        }
        if draft.tracksUnits {
            NumberField(title: "Quantity", value: $draft.quantity, identifier: "snapshot-quantity")
            NumberField(title: "Unit price", value: $draft.unitPrice, identifier: "snapshot-unit-price")
            LabeledContent("Value", value: draft.computedValue.currency)
        } else {
            NumberField(title: "Value", value: $draft.value, identifier: "snapshot-value")
        }
        NumberField(title: "Invested so far", value: $draft.invested, identifier: "snapshot-invested")
    }
}

// MARK: - Investment

struct InvestmentFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let investment: Investment?

    @State private var name: String
    @State private var ticker: String
    @State private var kind: InvestmentKind
    @State private var emoji: String
    /// First snapshot, only when creating.
    @State private var draft = SnapshotDraft()

    init(investment: Investment? = nil) {
        self.investment = investment
        _name = State(initialValue: investment?.name ?? "")
        _ticker = State(initialValue: investment?.ticker ?? "")
        _kind = State(initialValue: investment?.kind ?? .etf)
        _emoji = State(initialValue: investment?.displayEmoji ?? InvestmentKind.etf.emoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        EmojiBubble(emoji: emoji.isEmpty ? kind.emoji : emoji, color: kind.color, size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name (e.g. MSCI World)", text: $name)
                    TextField("Ticker (optional)", text: $ticker)
                        .textInputAutocapitalization(.characters)
                    Picker("Type", selection: $kind) {
                        ForEach(InvestmentKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                }
                if investment == nil {
                    Section {
                        SnapshotFields(draft: $draft)
                    } header: {
                        Text("Today")
                    } footer: {
                        Text("What it's worth now and how much you put in so far. You can update it any time with a new snapshot.")
                    }
                }
                Section("Emoji") {
                    EmojiPicker(emoji: $emoji, suggestions: EmojiPicker.investments)
                }
                if let investment {
                    Section {
                        Button("Delete this investment", role: .destructive) {
                            context.delete(investment)
                            dismiss()
                        }
                    }
                }
            }
            .themedForm()
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
            .onChange(of: kind) { old, new in
                // Follow the type until a custom emoji is picked
                if emoji == old.emoji { emoji = new.emoji }
            }
        }
    }

    /// Empty when it's just the type's default, so it follows type changes.
    private var customEmoji: String { emoji == kind.emoji ? "" : emoji }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let investment {
            investment.name = trimmed
            investment.ticker = ticker
            investment.kind = kind
            investment.emoji = customEmoji
        } else {
            let new = Investment(name: trimmed, ticker: ticker, kind: kind, emoji: customEmoji)
            context.insert(new)
            if draft.isValid {
                let snapshot = ValueSnapshot()
                draft.apply(to: snapshot)
                context.insert(snapshot)
                new.history.append(snapshot)
            }
        }
        dismiss()
    }
}

// MARK: - Snapshot

struct SnapshotFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let investment: Investment
    let snapshot: ValueSnapshot?

    @State private var draft: SnapshotDraft

    init(investment: Investment, snapshot: ValueSnapshot? = nil) {
        self.investment = investment
        self.snapshot = snapshot
        _draft = State(initialValue: snapshot.map { SnapshotDraft(from: $0, keepDate: true) }
            ?? SnapshotDraft(from: investment.latest))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SnapshotFields(draft: $draft)
                    TextField("Note", text: $draft.note)
                } footer: {
                    if snapshot == nil && investment.latest != nil {
                        Text("Pre-filled with the last snapshot: just change what moved.")
                    }
                }
                Section {
                    let gain = draft.computedValue - (draft.invested ?? 0)
                    LabeledContent("Gain") {
                        Text(gain.signedCurrency).foregroundStyle(Theme.gain(gain))
                    }
                }
                if let snapshot {
                    Section {
                        Button("Delete this snapshot", role: .destructive) {
                            investment.history.removeAll { $0 == snapshot }
                            context.delete(snapshot)
                            dismiss()
                        }
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(snapshot == nil ? "New snapshot" : "Edit snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!draft.isValid)
                }
            }
        }
    }

    private func save() {
        let item = snapshot ?? ValueSnapshot()
        draft.apply(to: item)
        if snapshot == nil {
            context.insert(item)
            investment.history.append(item)
        }
        dismiss()
    }
}

/// Snapshot of everything at once: every investment and loan, pre-filled
/// with their latest values.
struct SnapshotAllView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let investments: [Investment]
    let loans: [Loan]

    @State private var date = Date.now
    @State private var drafts: [PersistentIdentifier: SnapshotDraft] = [:]
    @State private var loanDrafts: [PersistentIdentifier: LoanDraft] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } footer: {
                    Text("Everything is pre-filled with the last snapshot: just change what moved.")
                }
                ForEach(investments) { investment in
                    Section {
                        SnapshotFields(draft: draft(for: investment), showsDate: false, showsUnitsToggle: false)
                    } header: {
                        HStack(spacing: 6) {
                            Moji(investment.displayEmoji, size: 18)
                            Text(investment.name)
                        }
                    }
                }
                ForEach(loans) { loan in
                    Section {
                        LoanFields(draft: loanDraft(for: loan))
                    } header: {
                        HStack(spacing: 6) {
                            Moji(loan.emoji, size: 18)
                            Text(loan.name)
                        }
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Snapshot of everything")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func draft(for investment: Investment) -> Binding<SnapshotDraft> {
        Binding(
            get: { drafts[investment.persistentModelID] ?? SnapshotDraft(from: investment.latest) },
            set: { drafts[investment.persistentModelID] = $0 }
        )
    }

    private func loanDraft(for loan: Loan) -> Binding<LoanDraft> {
        Binding(
            get: { loanDrafts[loan.persistentModelID] ?? LoanDraft(from: loan.latest, loan: loan) },
            set: { loanDrafts[loan.persistentModelID] = $0 }
        )
    }

    private func save() {
        for investment in investments {
            var draft = drafts[investment.persistentModelID] ?? SnapshotDraft(from: investment.latest)
            guard draft.isValid else { continue }
            draft.date = date
            draft.note = ""
            let snapshot = ValueSnapshot()
            draft.apply(to: snapshot)
            context.insert(snapshot)
            investment.history.append(snapshot)
        }
        for loan in loans {
            var draft = loanDrafts[loan.persistentModelID] ?? LoanDraft(from: loan.latest, loan: loan)
            guard draft.isValid else { continue }
            draft.date = date
            draft.note = ""
            let snapshot = LoanSnapshot()
            draft.apply(to: snapshot)
            context.insert(snapshot)
            loan.history.append(snapshot)
        }
        dismiss()
    }
}

// MARK: - Shared

/// A labeled decimal field with an optional value (empty = nil).
struct NumberField: View {
    let title: String
    @Binding var value: Double?
    var identifier: String?

    var body: some View {
        LabeledContent(title) {
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .accessibilityIdentifier(identifier ?? title)
        }
    }
}

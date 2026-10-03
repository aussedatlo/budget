import SwiftData
import SwiftUI

// MARK: - Snapshot draft

/// Editable copy of a position's values. It starts from the latest ones,
/// so updating a position is just changing what moved.
struct SnapshotDraft {
    var date = Date.now
    var tracksUnits = false
    var quantity: Double?
    var unitPrice: Double?
    var value: Double?
    var invested: Double?
    var note = ""
    /// Savings plan used to pre-fill "invested so far" in a new snapshot.
    private var plan: (invested: Double, since: Date, monthly: Double)?

    init() {}

    /// - Parameters:
    ///   - keepDate: true to edit `snapshot`, false to start a new one from it.
    ///   - monthlyContribution: savings plan added for each month since `snapshot`.
    init(from snapshot: ValueSnapshot?, keepDate: Bool = false, monthlyContribution: Double = 0) {
        guard let snapshot else { return }
        date = keepDate ? snapshot.date : .now
        tracksUnits = snapshot.tracksUnits
        quantity = snapshot.quantity
        unitPrice = snapshot.unitPrice
        value = snapshot.value
        invested = snapshot.invested
        note = keepDate ? snapshot.note : ""
        if !keepDate && monthlyContribution > 0 {
            plan = (snapshot.invested, snapshot.date, monthlyContribution)
            applyPlan()
        }
    }

    /// Money added by the savings plan since the previous snapshot.
    var plannedAddition: Double {
        guard let plan else { return 0 }
        return plan.monthly * Double(Calendar.current.monthsBetween(plan.since, date))
    }

    /// Recompute "invested so far" from the plan, e.g. after a date change.
    mutating func applyPlan() {
        guard let plan else { return }
        invested = plan.invested + plannedAddition
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
                .onChange(of: draft.date) { draft.applyPlan() }
        }
        if showsUnitsToggle {
            Toggle("Quantity × unit price", isOn: $draft.tracksUnits.animation(.snappy))
        }
        if draft.tracksUnits {
            NumberField(title: "Quantity", value: $draft.quantity, identifier: "snapshot-quantity")
            NumberField(title: "Unit price", value: $draft.unitPrice, identifier: "snapshot-unit-price")
            LabeledContent("Value", value: draft.computedValue.currency)
        } else {
            NumberField(title: "Value", value: $draft.value, identifier: "snapshot-value")
        }
        NumberField(title: "Invested so far", value: $draft.invested, identifier: "snapshot-invested")
        if draft.plannedAddition > 0 {
            Text("Includes \(draft.plannedAddition.signedCurrency) from the savings plan. Change it if this month was different.")
                .font(.footnote)
                .foregroundStyle(Theme.softInk)
        }
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
    @State private var monthlyContribution: Double?
    /// First snapshot, only when creating.
    @State private var draft = SnapshotDraft()

    init(investment: Investment? = nil) {
        self.investment = investment
        _name = State(initialValue: investment?.name ?? "")
        _ticker = State(initialValue: investment?.ticker ?? "")
        _kind = State(initialValue: investment?.kind ?? .etf)
        _emoji = State(initialValue: investment?.displayEmoji ?? InvestmentKind.etf.emoji)
        _monthlyContribution = State(initialValue: investment.flatMap { $0.monthlyContribution > 0 ? $0.monthlyContribution : nil })
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
                Section {
                    NumberField(title: "Monthly savings", value: $monthlyContribution, identifier: "monthly-contribution")
                } header: {
                    Text("Savings plan")
                } footer: {
                    Text("How much you usually add every month. It's added to “invested so far” for you when you update the values, and it's set aside on the Month screen.")
                }
                if investment == nil {
                    Section {
                        SnapshotFields(draft: $draft)
                    } header: {
                        Text("Today")
                    } footer: {
                        Text("What it's worth now and how much you put in so far. You can update it any time.")
                    }
                }
                Section("Icon") {
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
            investment.monthlyContribution = monthlyContribution ?? 0
        } else {
            let new = Investment(name: trimmed, ticker: ticker, kind: kind, emoji: customEmoji)
            new.monthlyContribution = monthlyContribution ?? 0
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

// MARK: - Values

/// Updates what a position is worth (no `snapshot`), or corrects past values.
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
            ?? SnapshotDraft(from: investment.latest, monthlyContribution: investment.monthlyContribution))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SnapshotFields(draft: $draft)
                    TextField("Note", text: $draft.note)
                } footer: {
                    if snapshot == nil && investment.latest != nil {
                        Text("Pre-filled with the current values: just change what moved.")
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
                        Button("Delete these values", role: .destructive) {
                            investment.history.removeAll { $0 == snapshot }
                            context.delete(snapshot)
                            dismiss()
                        }
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(snapshot == nil ? "Update values" : "Edit past values")
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
        // One set of values per day: updating twice the same day corrects it
        let existing = snapshot ?? investment.entry(on: draft.date)
        let item = existing ?? ValueSnapshot()
        draft.apply(to: item)
        if existing == nil {
            context.insert(item)
            investment.history.append(item)
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
            DecimalField(value: $value)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(identifier ?? title)
        }
    }
}

/// A decimal text field that updates its value on every keystroke.
/// (`TextField(value:format:)` only commits when the field loses focus,
/// and the decimal keypad has no Return key: tapping Save right after
/// typing would keep the old value.)
struct DecimalField: View {
    @Binding var value: Double?
    @State private var text = ""

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.decimalPad)
            .monospacedDigit()
            .onAppear { text = Self.format(value) }
            .onChange(of: text) { value = Self.parse(text) }
            .onChange(of: value) {
                // Changed from outside (e.g. the savings plan): show it
                if Self.parse(text) != value { text = Self.format(value) }
            }
    }

    static func parse(_ text: String) -> Double? {
        let cleaned = text.filter { !$0.isWhitespace && $0 != "\u{202F}" && $0 != "\u{00A0}" }
        guard !cleaned.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let number = formatter.number(from: cleaned) { return number.doubleValue }
        // Accept both "12.5" and "12,5" whatever the region
        return Double(cleaned.replacingOccurrences(of: ",", with: "."))
    }

    static func format(_ value: Double?) -> String {
        value.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...6))) } ?? ""
    }
}

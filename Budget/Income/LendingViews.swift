import Charts
import SwiftData
import SwiftUI

// MARK: - Card

/// Money lent and how much has come back, shown on the Income screen.
struct LendingCard: View {
    let lending: Lending

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                EmojiBubble(emoji: lending.emoji, color: Theme.sky)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lending.name)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.softInk)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(lending.remaining.currency)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(lending.isSettled ? Theme.positive : Theme.ink)
                    Text("left to repay")
                        .font(.caption)
                        .foregroundStyle(Theme.softInk)
                }
            }
            LoanProgressBar(ratio: lending.repaidRatio)
            HStack {
                StatTile(title: "Already repaid", value: lending.repaid.currency, color: Theme.positive)
                StatTile(title: "Lent", value: lending.lent.currency)
            }
        }
        .card()
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if lending.isSettled { return "All repaid" }
        if lending.monthlyRepayment > 0 { return "\(lending.monthlyRepayment.currency) a month" }
        return "Since \(lending.date.formatted(date: .abbreviated, time: .omitted))"
    }
}

// MARK: - Detail

struct LendingDetailView: View {
    let lending: Lending

    @State private var showingEdit = false
    @State private var adding = false
    @State private var editing: Repayment?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LendingCard(lending: lending)

                HStack(spacing: 10) {
                    tile("Lent on", lending.date.formatted(date: .abbreviated, time: .omitted))
                    tile("Monthly repayment", lending.monthlyRepayment > 0 ? lending.monthlyRepayment.currency : "–")
                }

                LendingChart(lending: lending).card()

                SectionTitle(title: "Repayments")
                ForEach(lending.sortedRepayments) { repayment in
                    Button { editing = repayment } label: { RepaymentRow(repayment: repayment) }
                        .buttonStyle(SquishyButtonStyle())
                }
                Button("Add repayment", systemImage: "plus") { adding = true }
                    .buttonStyle(PillButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .animation(.snappy, value: lending.repayments.count)
        }
        .background(Theme.background)
        .navigationTitle(lending.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { showingEdit = true } }
        .sheet(isPresented: $showingEdit) { LendingFormView(lending: lending) }
        .sheet(isPresented: $adding) { RepaymentFormView(lending: lending) }
        .sheet(item: $editing) { RepaymentFormView(lending: lending, repayment: $0) }
        .sensoryFeedback(.success, trigger: lending.repayments.count) { old, new in new > old }
    }

    private func tile(_ title: String, _ value: String) -> some View {
        StatTile(title: title, value: value)
            .card(padding: 12)
    }
}

/// What's left to repay going down with each repayment.
private struct LendingChart: View {
    let lending: Lending

    private struct Point {
        let date: Date
        let remaining: Double
    }

    private var chartPoints: [Point] {
        var left = lending.lent
        var points = [Point(date: lending.date, remaining: left)]
        for repayment in lending.repayments.sorted(by: { $0.date < $1.date }) {
            left = max(left - repayment.amount, 0)
            points.append(Point(date: max(repayment.date, lending.date), remaining: left))
        }
        // Carry what's left up to today, so the last repayment shows as a step
        if points.count > 1, let last = points.last, last.date < .now {
            points.append(Point(date: .now, remaining: last.remaining))
        }
        return points
    }

    var body: some View {
        let points = chartPoints
        if points.count < 2 {
            Text("Add repayments as they come in to see what's left go down.")
                .font(.footnote)
                .foregroundStyle(Theme.softInk)
        } else {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    AreaMark(x: .value("Date", point.date), y: .value("Left to repay", point.remaining))
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.accent.opacity(0.18), Theme.accent.opacity(0.0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("Date", point.date), y: .value("Left to repay", point.remaining))
                        .interpolationMethod(.stepEnd)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .foregroundStyle(Theme.accent)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 170)
        }
    }
}

private struct RepaymentRow: View {
    let repayment: Repayment

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(repayment.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                if !repayment.note.isEmpty {
                    Text(repayment.note).font(.caption).foregroundStyle(Theme.softInk)
                }
            }
            Spacer()
            Text(repayment.amount.signedCurrency)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(Theme.positive)
        }
        .card(padding: 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Forms

struct LendingFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let lending: Lending?

    @State private var name: String
    @State private var emoji: String
    @State private var lent: Double?
    @State private var date: Date
    @State private var monthlyRepayment: Double?

    init(lending: Lending? = nil) {
        self.lending = lending
        _name = State(initialValue: lending?.name ?? "")
        _emoji = State(initialValue: lending?.emoji ?? "💸")
        _lent = State(initialValue: lending?.lent)
        _date = State(initialValue: lending?.date ?? .now)
        _monthlyRepayment = State(initialValue: lending.flatMap { $0.monthlyRepayment > 0 ? $0.monthlyRepayment : nil })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        EmojiBubble(emoji: emoji.isEmpty ? "💸" : emoji, color: Theme.sky, size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Lent to (e.g. Lucas)", text: $name)
                        .accessibilityIdentifier("lending-name")
                    NumberField(title: "Amount lent", value: $lent, identifier: "lending-amount")
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    NumberField(title: "Monthly repayment", value: $monthlyRepayment, identifier: "lending-monthly")
                } footer: {
                    Text("Optional. Counted as income each month until it's all repaid. Log each repayment from the loan page when it comes in.")
                }
                Section("Icon") {
                    EmojiPicker(emoji: $emoji, suggestions: EmojiPicker.lending)
                }
                if let lending {
                    Section {
                        Button("Delete this loan", role: .destructive) {
                            context.delete(lending)
                            dismiss()
                        }
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(lending == nil ? "New money lent" : "Edit money lent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (lent ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        let item = lending ?? Lending(name: "", lent: 0)
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.emoji = emoji.isEmpty ? "💸" : emoji
        item.lent = lent ?? 0
        item.date = date
        item.monthlyRepayment = max(monthlyRepayment ?? 0, 0)
        if lending == nil { context.insert(item) }
        dismiss()
    }
}

struct RepaymentFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let lending: Lending
    let repayment: Repayment?

    @State private var date: Date
    @State private var amount: Double?
    @State private var note: String

    init(lending: Lending, repayment: Repayment? = nil) {
        self.lending = lending
        self.repayment = repayment
        _date = State(initialValue: repayment?.date ?? .now)
        // A new repayment starts from the usual monthly amount
        let suggested = lending.monthlyRepayment > 0 ? min(lending.monthlyRepayment, lending.remaining) : nil
        _amount = State(initialValue: repayment?.amount ?? suggested)
        _note = State(initialValue: repayment?.note ?? "")
    }

    /// What would be left after this repayment.
    private var leftAfter: Double {
        max(lending.remaining + (repayment?.amount ?? 0) - (amount ?? 0), 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    NumberField(title: "Amount", value: $amount, identifier: "repayment-amount")
                    TextField("Note", text: $note)
                }
                Section {
                    LabeledContent("Left to repay after", value: leftAfter.currency)
                }
                if let repayment {
                    Section {
                        Button("Delete this repayment", role: .destructive) {
                            lending.repayments.removeAll { $0 == repayment }
                            context.delete(repayment)
                            dismiss()
                        }
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(repayment == nil ? "New repayment" : "Edit repayment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled((amount ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        let item = repayment ?? Repayment()
        item.date = date
        item.amount = amount ?? 0
        item.note = note
        if repayment == nil {
            context.insert(item)
            lending.repayments.append(item)
        }
        dismiss()
    }
}

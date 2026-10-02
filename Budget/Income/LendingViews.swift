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
            LoanProgressBar(ratio: lending.repaidRatio, color: Theme.lent)
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
    @State private var editing: LendingSnapshot?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LendingCard(lending: lending)

                HStack(spacing: 10) {
                    tile("Lent on", lending.date.formatted(date: .abbreviated, time: .omitted))
                    tile("Monthly repayment", lending.monthlyRepayment > 0 ? lending.monthlyRepayment.currency : "–")
                }

                LendingChart(lending: lending).card()

                SectionTitle(title: "Snapshots")
                ForEach(lending.sortedHistory) { snapshot in
                    Button { editing = snapshot } label: { LendingSnapshotRow(snapshot: snapshot) }
                        .buttonStyle(SquishyButtonStyle())
                }
                Button("New snapshot", systemImage: "plus") { adding = true }
                    .buttonStyle(PillButtonStyle(color: Theme.lent))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .animation(.snappy, value: lending.history.count)
        }
        .background(Theme.background)
        .navigationTitle(lending.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { showingEdit = true } }
        .sheet(isPresented: $showingEdit) { LendingFormView(lending: lending) }
        .sheet(isPresented: $adding) { LendingSnapshotFormView(lending: lending) }
        .sheet(item: $editing) { LendingSnapshotFormView(lending: lending, snapshot: $0) }
        .sensoryFeedback(.success, trigger: lending.history.count) { old, new in new > old }
    }

    private func tile(_ title: String, _ value: String) -> some View {
        StatTile(title: title, value: value)
            .card(padding: 12)
    }
}

/// What's left to repay going down, from the amount lent through each snapshot.
private struct LendingChart: View {
    let lending: Lending

    private struct Point {
        let date: Date
        let remaining: Double
    }

    private var chartPoints: [Point] {
        var points = [Point(date: lending.date, remaining: lending.lent)]
        for snapshot in lending.history.sorted(by: { $0.date < $1.date }) where snapshot.date >= lending.date {
            points.append(Point(date: snapshot.date, remaining: snapshot.remaining))
        }
        return points
    }

    var body: some View {
        let points = chartPoints
        if points.count < 2 {
            Text("Add a snapshot from time to time to see what's left go down.")
                .font(.footnote)
                .foregroundStyle(Theme.softInk)
        } else {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    AreaMark(x: .value("Date", point.date), y: .value("Left to repay", point.remaining))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.lent.opacity(0.18), Theme.lent.opacity(0.0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("Date", point.date), y: .value("Left to repay", point.remaining))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .foregroundStyle(Theme.lent)
                    PointMark(x: .value("Date", point.date), y: .value("Left to repay", point.remaining))
                        .symbolSize(24)
                        .foregroundStyle(Theme.lent)
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

private struct LendingSnapshotRow: View {
    let snapshot: LendingSnapshot

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                if !snapshot.note.isEmpty {
                    Text(snapshot.note).font(.caption).foregroundStyle(Theme.softInk)
                }
            }
            Spacer()
            Text(snapshot.remaining.currency)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
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
    /// Corrects the latest snapshot when editing.
    @State private var remaining: Double?

    init(lending: Lending? = nil) {
        self.lending = lending
        _name = State(initialValue: lending?.name ?? "")
        _emoji = State(initialValue: lending?.emoji ?? "💸")
        _lent = State(initialValue: lending?.lent)
        _date = State(initialValue: lending?.date ?? .now)
        _monthlyRepayment = State(initialValue: lending.flatMap { $0.monthlyRepayment > 0 ? $0.monthlyRepayment : nil })
        _remaining = State(initialValue: lending?.latest?.remaining)
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
                if let latest = lending?.latest {
                    Section {
                        NumberField(title: "Left to repay", value: $remaining, identifier: "lending-remaining")
                    } header: {
                        Text("Latest snapshot · \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                    } footer: {
                        Text("Corrects the latest snapshot. To keep the history, add a new snapshot from the loan page instead.")
                    }
                }
                Section {
                    NumberField(title: "Monthly repayment", value: $monthlyRepayment, identifier: "lending-monthly")
                } footer: {
                    Text("Optional. Counted as income each month until it's all repaid. Update what's left with a snapshot from time to time.")
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
        if let latest = item.latest, let remaining {
            latest.remaining = max(remaining, 0)
        }
        if lending == nil { context.insert(item) }
        dismiss()
    }
}

struct LendingSnapshotFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let lending: Lending
    let snapshot: LendingSnapshot?

    @State private var date: Date
    @State private var remaining: Double?
    @State private var note: String

    init(lending: Lending, snapshot: LendingSnapshot? = nil) {
        self.lending = lending
        self.snapshot = snapshot
        _date = State(initialValue: snapshot?.date ?? .now)
        // A new snapshot starts from what was left last time
        _remaining = State(initialValue: snapshot?.remaining ?? lending.remaining)
        _note = State(initialValue: snapshot?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    NumberField(title: "Left to repay", value: $remaining, identifier: "lending-remaining")
                    TextField("Note", text: $note)
                } footer: {
                    if snapshot == nil {
                        Text("Pre-filled with what was left last time: just change it.")
                    }
                }
                Section {
                    LabeledContent("Already repaid", value: max(lending.lent - (remaining ?? 0), 0).currency)
                }
                if let snapshot {
                    Section {
                        Button("Delete this snapshot", role: .destructive) {
                            lending.history.removeAll { $0 == snapshot }
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
                    Button("Save", action: save).disabled(remaining == nil)
                }
            }
        }
    }

    private func save() {
        let item = snapshot ?? LendingSnapshot()
        item.date = date
        item.remaining = max(remaining ?? 0, 0)
        item.note = note
        if snapshot == nil {
            context.insert(item)
            lending.history.append(item)
        }
        dismiss()
    }
}

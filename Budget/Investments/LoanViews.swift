import Charts
import SwiftData
import SwiftUI

// MARK: - Draft & fields

/// Editable copy of a loan snapshot, pre-filled from the previous one.
struct LoanDraft {
    var date = Date.now
    var remaining: Double?
    var homeValue: Double?
    var note = ""

    init() {}

    init(from snapshot: LoanSnapshot?, loan: Loan? = nil, keepDate: Bool = false) {
        if let snapshot {
            date = keepDate ? snapshot.date : .now
            remaining = snapshot.remaining
            homeValue = snapshot.homeValue
            note = keepDate ? snapshot.note : ""
        } else if let loan {
            remaining = loan.borrowed
        }
    }

    var isValid: Bool { remaining != nil }

    func apply(to snapshot: LoanSnapshot) {
        snapshot.date = date
        snapshot.remaining = remaining ?? 0
        snapshot.homeValue = homeValue ?? 0
        snapshot.note = note
    }
}

struct LoanFields: View {
    @Binding var draft: LoanDraft

    var body: some View {
        NumberField(title: "Left to repay", value: $draft.remaining, identifier: "loan-remaining")
        NumberField(title: "Home value", value: $draft.homeValue, identifier: "loan-home-value")
    }
}

// MARK: - Card

/// Loan progress shown on the Investments screen.
struct LoanCard: View {
    let loan: Loan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                EmojiBubble(emoji: loan.emoji, color: Theme.card.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.name)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    if loan.homeValue > 0 {
                        TextWithMoji(
                            text: "\(loan.equityRatio.formatted(.percent.precision(.fractionLength(0)))) of the home is ours",
                            emoji: "💖", size: 14
                        )
                            .font(.caption)
                            .foregroundStyle(Theme.softInk)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(loan.equity.currency)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("ours")
                        .font(.caption)
                        .foregroundStyle(Theme.softInk)
                }
            }
            LoanProgressBar(ratio: loan.repaidRatio)
            HStack {
                StatTile(title: "Already repaid", value: loan.repaid.currency, color: Theme.positive)
                StatTile(title: "Left to repay", value: loan.remaining.currency)
            }
        }
        .card(LinearGradient(colors: [Theme.peach, Theme.butter], startPoint: .topLeading, endPoint: .bottomTrailing))
        .contentShape(Rectangle())
    }
}

/// A rounded bar with a little house travelling along it.
struct LoanProgressBar: View {
    let ratio: Double

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.card.opacity(0.7))
                Capsule()
                    .fill(LinearGradient(colors: [Theme.accent.opacity(0.7), Theme.accent],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(width * ratio, 14))
                Moji("🏡", size: 20)
                    .offset(x: min(max(width * ratio - 12, 0), width - 22))
            }
            .animation(.spring(duration: 1, bounce: 0.3), value: ratio)
        }
        .frame(height: 14)
        .padding(.vertical, 4)
        .accessibilityElement()
        .accessibilityLabel("Repaid")
        .accessibilityValue(ratio.formatted(.percent.precision(.fractionLength(0))))
    }
}

// MARK: - Detail

struct LoanDetailView: View {
    @Environment(\.modelContext) private var context
    let loan: Loan

    @State private var showingEdit = false
    @State private var adding = false
    @State private var editing: LoanSnapshot?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LoanCard(loan: loan)

                HStack(spacing: 10) {
                    tile("🏦", "Borrowed", loan.borrowed.currency, Theme.sky)
                    tile("🏡", "Home value", loan.homeValue > 0 ? loan.homeValue.currency : "–", Theme.mint)
                }

                LoanChart(loan: loan).card()

                SectionTitle(title: "Snapshots")
                ForEach(loan.sortedHistory) { snapshot in
                    Button { editing = snapshot } label: { LoanSnapshotRow(snapshot: snapshot) }
                        .buttonStyle(SquishyButtonStyle())
                }
                Button("New snapshot", systemImage: "camera.fill") { adding = true }
                    .buttonStyle(PillButtonStyle(color: Theme.positive))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .animation(.bouncy, value: loan.history.count)
        }
        .background(Theme.background)
        .navigationTitle(loan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { showingEdit = true } }
        .sheet(isPresented: $showingEdit) { LoanFormView(loan: loan) }
        .sheet(isPresented: $adding) { LoanSnapshotFormView(loan: loan) }
        .sheet(item: $editing) { LoanSnapshotFormView(loan: loan, snapshot: $0) }
        .sensoryFeedback(.success, trigger: loan.history.count) { old, new in new > old }
    }

    private func tile(_ emoji: String, _ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Moji(emoji, size: 26)
            StatTile(title: title, value: value)
        }
        .card(color, padding: 12)
    }
}

/// What's left to repay going down, and the home value.
private struct LoanChart: View {
    let loan: Loan

    var body: some View {
        let points = loan.history.sorted { $0.date < $1.date }
        if points.count < 2 {
            TextWithMoji(text: "Add a snapshot from time to time to watch the loan melt", emoji: "🍦", size: 16)
                .font(.footnote)
                .foregroundStyle(Theme.softInk)
        } else {
            Chart {
                ForEach(points) { point in
                    AreaMark(x: .value("Date", point.date), y: .value("Amount", point.remaining))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("Date", point.date), y: .value("Amount", point.remaining),
                             series: .value("Series", "Left to repay"))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(by: .value("Series", "Left to repay"))
                    if point.homeValue > 0 {
                        LineMark(x: .value("Date", point.date), y: .value("Amount", point.homeValue),
                                 series: .value("Series", "Home value"))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                            .foregroundStyle(by: .value("Series", "Home value"))
                    }
                }
            }
            .chartForegroundStyleScale(["Left to repay": Theme.accent, "Home value": Theme.positive])
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.year())
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 170)
        }
    }
}

private struct LoanSnapshotRow: View {
    let snapshot: LoanSnapshot

    var body: some View {
        HStack(spacing: 12) {
            EmojiBubble(emoji: "📸", color: Theme.lavender, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                if !snapshot.note.isEmpty {
                    Text(snapshot.note).font(.caption).foregroundStyle(Theme.softInk)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(snapshot.remaining.currency)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                if snapshot.homeValue > 0 {
                    Text("Home \(snapshot.homeValue.currency)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.softInk)
                }
            }
        }
        .card(padding: 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Forms

struct LoanFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let loan: Loan?

    @State private var name: String
    @State private var emoji: String
    @State private var borrowed: Double?
    /// First snapshot, only when creating.
    @State private var draft = LoanDraft()

    init(loan: Loan? = nil) {
        self.loan = loan
        _name = State(initialValue: loan?.name ?? "Our home")
        _emoji = State(initialValue: loan?.emoji ?? "🏠")
        _borrowed = State(initialValue: loan?.borrowed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        EmojiBubble(emoji: emoji.isEmpty ? "🏠" : emoji, color: Theme.peach, size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name", text: $name)
                    NumberField(title: "Amount borrowed", value: $borrowed, identifier: "loan-borrowed")
                }
                if loan == nil {
                    Section {
                        LoanFields(draft: $draft)
                    } header: {
                        Text("Today")
                    } footer: {
                        Text("“Left to repay” is on your bank statement. The home value is your best estimate; you can update both with a new snapshot.")
                    }
                }
                Section("Emoji") {
                    EmojiPicker(emoji: $emoji, suggestions: EmojiPicker.homes)
                }
                if let loan {
                    Section {
                        Button("Delete this loan", role: .destructive) {
                            context.delete(loan)
                            dismiss()
                        }
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(loan == nil ? "New home loan" : "Edit loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (borrowed ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let loan {
            loan.name = trimmed
            loan.emoji = emoji.isEmpty ? "🏠" : emoji
            loan.borrowed = borrowed ?? 0
        } else {
            let new = Loan(name: trimmed, emoji: emoji.isEmpty ? "🏠" : emoji, borrowed: borrowed ?? 0)
            context.insert(new)
            if draft.isValid {
                let snapshot = LoanSnapshot()
                draft.apply(to: snapshot)
                context.insert(snapshot)
                new.history.append(snapshot)
            }
        }
        dismiss()
    }
}

struct LoanSnapshotFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let loan: Loan
    let snapshot: LoanSnapshot?

    @State private var draft: LoanDraft

    init(loan: Loan, snapshot: LoanSnapshot? = nil) {
        self.loan = loan
        self.snapshot = snapshot
        _draft = State(initialValue: snapshot.map { LoanDraft(from: $0, keepDate: true) }
            ?? LoanDraft(from: loan.latest, loan: loan))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                    LoanFields(draft: $draft)
                    TextField("Note", text: $draft.note)
                } footer: {
                    if snapshot == nil && loan.latest != nil {
                        Text("Pre-filled with the last snapshot: just change what moved.")
                    }
                }
                Section {
                    LabeledContent("Already repaid", value: max(loan.borrowed - (draft.remaining ?? 0), 0).currency)
                    LabeledContent("Ours", value: ((draft.homeValue ?? 0) - (draft.remaining ?? 0)).currency)
                }
                if let snapshot {
                    Section {
                        Button("Delete this snapshot", role: .destructive) {
                            loan.history.removeAll { $0 == snapshot }
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
        let item = snapshot ?? LoanSnapshot()
        draft.apply(to: item)
        if snapshot == nil {
            context.insert(item)
            loan.history.append(item)
        }
        dismiss()
    }
}

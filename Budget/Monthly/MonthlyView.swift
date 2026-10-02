import SwiftData
import SwiftUI

/// Monthly income minus recurring charges: what's left each month,
/// shown as a jar that fills up.
struct MonthlyView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FixedCharge.dayOfMonth) private var charges: [FixedCharge]
    @AppStorage(AppSettings.incomeKey) private var income: Double = 0
    @Binding var showingSettings: Bool
    @State private var adding = false
    @State private var editing: FixedCharge?

    private var total: Double { charges.reduce(0) { $0 + $1.amount } }
    private var left: Double { income - total }
    private var level: Double { income > 0 ? max(left, 0) / income : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    incomeCard
                    SectionTitle(title: "Every month", trailing: total.currency)
                    if charges.isEmpty {
                        emptyState
                    }
                    ForEach(charges) { charge in
                        Button { editing = charge } label: { ChargeCard(charge: charge) }
                            .buttonStyle(SquishyButtonStyle())
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = charge }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    withAnimation(.bouncy) { context.delete(charge) }
                                }
                            }
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .animation(.bouncy, value: charges.count)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("Our month")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: {
                        Label("Add charge", systemImage: "plus.circle.fill")
                            .symbolEffect(.bounce, value: charges.count)
                    }
                }
            }
            .sheet(isPresented: $adding) { FixedChargeFormView() }
            .sheet(item: $editing) { FixedChargeFormView(charge: $0) }
            .sensoryFeedback(.success, trigger: charges.count) { old, new in new > old }
            .sensoryFeedback(.impact(weight: .light), trigger: charges.count) { old, new in new < old }
        }
    }

    // MARK: - Header with the jar

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            JarView(level: level)
                .frame(width: 118)
            VStack(alignment: .leading, spacing: 6) {
                Text(left >= 0 ? "You have" : "Oops, over by")
                    .font(.subheadline)
                    .foregroundStyle(Theme.softInk)
                Text(abs(left).currency)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(left >= 0 ? Theme.ink : Theme.negative)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: left))
                    .animation(.snappy, value: left)
                TextWithMoji(text: message.text, emoji: message.emoji, size: 18)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .animation(.default, value: message.text)
                HStack(spacing: 6) {
                    Chip(text: income.currency, emoji: "💰")
                    Chip(text: total.currency, emoji: "🧾")
                }
                .padding(.top, 2)
            }
        }
        .card(LinearGradient(colors: [Theme.pink, Theme.peach], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var message: (text: String, emoji: String) {
        if income <= 0 { return ("Add your income to fill the jar", "✨") }
        switch level {
        case 0.5...: return ("left this month, lovely!", "🌸")
        case 0.2..<0.5: return ("left this month", "💖")
        case 0.0001..<0.2: return ("left, a bit tight", "🍃")
        default: return left < 0 ? ("this month", "🙈") : ("left, the jar is empty", "🥺")
        }
    }

    private var incomeCard: some View {
        HStack {
            EmojiBubble(emoji: "💰", color: Theme.butter, size: 40)
            Text("Monthly income")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Spacer()
            TextField("0", value: $income, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: 140)
                .accessibilityIdentifier("monthly-income")
        }
        .card()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Moji("🏠", size: 40)
                Moji("📺", size: 40)
                Moji("🚗", size: 40)
            }
            Text("Add rent, subscriptions, insurance…\nanything paid every month.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.softInk)
            Button("Add a charge") { adding = true }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

private struct ChargeCard: View {
    let charge: FixedCharge

    var body: some View {
        HStack(spacing: 12) {
            EmojiBubble(emoji: charge.displayEmoji, color: charge.category.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(charge.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Day \(charge.dayOfMonth) · \(charge.category.label)")
                    .font(.caption)
                    .foregroundStyle(Theme.softInk)
            }
            Spacer()
            Text(charge.amount.currency)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .card(padding: 12)
        .contentShape(Rectangle())
    }
}

struct FixedChargeFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let charge: FixedCharge?

    @State private var title: String
    @State private var amount: Double?
    @State private var category: ChargeCategory
    @State private var dayOfMonth: Int
    @State private var emoji: String

    init(charge: FixedCharge? = nil) {
        self.charge = charge
        _title = State(initialValue: charge?.title ?? "")
        _amount = State(initialValue: charge?.amount)
        _category = State(initialValue: charge?.category ?? .housing)
        _dayOfMonth = State(initialValue: charge?.dayOfMonth ?? 1)
        _emoji = State(initialValue: charge?.displayEmoji ?? ChargeCategory.housing.emoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        EmojiBubble(emoji: emoji.isEmpty ? category.emoji : emoji, color: category.color, size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Title (e.g. Rent)", text: $title)
                        .accessibilityIdentifier("charge-title")
                    NumberField(title: "Amount", value: $amount, identifier: "charge-amount")
                    Picker("Category", selection: $category) {
                        ForEach(ChargeCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    Stepper("Day of month: \(dayOfMonth)", value: $dayOfMonth, in: 1...31)
                }
                Section("Emoji") {
                    EmojiPicker(emoji: $emoji, suggestions: EmojiPicker.charges)
                }
                if let charge {
                    Section {
                        Button("Delete this charge", role: .destructive) {
                            context.delete(charge)
                            dismiss()
                        }
                    }
                }
            }
            .themedForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(charge == nil ? "New charge" : "Edit charge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || (amount ?? 0) <= 0)
                }
            }
            .onChange(of: category) { old, new in
                // Follow the category until a custom emoji is picked
                if emoji == old.emoji { emoji = new.emoji }
            }
        }
    }

    private func save() {
        let item = charge ?? FixedCharge(title: "", amount: 0)
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.amount = amount ?? 0
        item.category = category
        item.dayOfMonth = dayOfMonth
        item.emoji = emoji == category.emoji ? "" : emoji
        if charge == nil { context.insert(item) }
        dismiss()
    }
}

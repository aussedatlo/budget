import Charts
import SwiftData
import SwiftUI

struct ExpensesView: View {
    @AppStorage(AppSettings.budgetKey) private var budget: Double = 0
    @State private var month = Date.now
    @State private var showingAdd = false
    @State private var showingFixed = false

    private var calendar: Calendar { .current }
    private var isCurrentMonth: Bool { calendar.isDate(month, equalTo: .now, toGranularity: .month) }

    var body: some View {
        NavigationStack {
            MonthExpensesView(month: month, budget: budget)
                // New list per month: switching months starts back at the summary
                .id(calendar.monthInterval(for: month).start)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 16) {
                            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                                .accessibilityLabel("Previous month")
                            Text(month.formatted(.dateTime.month(.wide).year()))
                                .font(.headline)
                                .frame(minWidth: 140)
                                .onTapGesture { month = .now }
                            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                                .accessibilityLabel("Next month")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingFixed = true } label: {
                            Label("Fixed charges", systemImage: "repeat")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingAdd = true } label: {
                            Label("Add expense", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAdd) {
                    ExpenseFormView(defaultDate: isCurrentMonth ? .now : calendar.monthInterval(for: month).start)
                }
                .sheet(isPresented: $showingFixed) { FixedChargesView() }
        }
    }

    private func shiftMonth(_ delta: Int) {
        month = calendar.date(byAdding: .month, value: delta, to: month) ?? month
    }
}

private struct CategoryTotal: Identifiable {
    let category: ExpenseCategory
    let amount: Double
    var id: String { category.id }
}

private struct MonthExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query private var expenses: [Expense]
    @Query(sort: \FixedCharge.dayOfMonth) private var allFixedCharges: [FixedCharge]
    @State private var editing: Expense?

    let interval: DateInterval
    let budget: Double

    init(month: Date, budget: Double) {
        let interval = Calendar.current.monthInterval(for: month)
        let start = interval.start
        let end = interval.end
        _expenses = Query(
            filter: #Predicate<Expense> { $0.date >= start && $0.date < end },
            sort: \Expense.date,
            order: .reverse
        )
        self.interval = interval
        self.budget = budget
    }

    private var fixedCharges: [FixedCharge] { allFixedCharges.filter { $0.applies(to: interval) } }
    private var variableTotal: Double { expenses.reduce(0) { $0 + $1.amount } }
    private var fixedTotal: Double { fixedCharges.reduce(0) { $0 + $1.amount } }
    private var total: Double { variableTotal + fixedTotal }

    private var byCategory: [CategoryTotal] {
        var totals: [ExpenseCategory: Double] = [:]
        for expense in expenses { totals[expense.category, default: 0] += expense.amount }
        for charge in fixedCharges { totals[charge.category, default: 0] += charge.amount }
        return totals
            .map { CategoryTotal(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        List {
            Section { summary }

            if total > 0 {
                Section("By category") { categoryBreakdown }
            }

            if !fixedCharges.isEmpty {
                Section {
                    ForEach(fixedCharges) { charge in
                        ExpenseRowContent(
                            title: charge.title,
                            subtitle: "Every month, day \(charge.dayOfMonth)",
                            amount: charge.amount,
                            category: charge.category
                        )
                    }
                } header: {
                    HStack {
                        Text("Fixed charges")
                        Spacer()
                        Text(fixedTotal.currency)
                    }
                }
            }

            Section {
                if expenses.isEmpty {
                    Text("No expenses this month. Tap + to add one.")
                        .foregroundStyle(.secondary)
                }
                ForEach(expenses) { expense in
                    Button { editing = expense } label: {
                        ExpenseRowContent(
                            title: expense.title.isEmpty ? expense.category.label : expense.title,
                            subtitle: expense.date.formatted(.dateTime.weekday(.abbreviated).day().month()),
                            amount: expense.amount,
                            category: expense.category
                        )
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(expenses[index]) }
                }
            } header: {
                HStack {
                    Text("Expenses")
                    Spacer()
                    Text(variableTotal.currency)
                }
            }
        }
        .sheet(item: $editing) { ExpenseFormView(expense: $0) }
    }

    @ViewBuilder
    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Spent this month").font(.caption).foregroundStyle(.secondary)
                Text(total.currency).font(.largeTitle.bold()).monospacedDigit()
            }
            if budget > 0 {
                let remaining = budget - total
                ProgressView(value: min(total, budget), total: budget)
                    .tint(remaining < 0 ? Color.red : total > budget * 0.8 ? Color.orange : Color.green)
                HStack {
                    StatTile(title: "Budget", value: budget.currency)
                    StatTile(
                        title: remaining < 0 ? "Over budget" : "Remaining",
                        value: abs(remaining).currency,
                        color: remaining < 0 ? .red : .primary
                    )
                }
            } else {
                Text("Set a monthly budget in Settings to track what's left.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack {
                StatTile(title: "Fixed", value: fixedTotal.currency)
                StatTile(title: "Variable", value: variableTotal.currency)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var categoryBreakdown: some View {
        Chart(byCategory) { item in
            SectorMark(
                angle: .value("Amount", item.amount),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(item.category.color)
        }
        .frame(height: 160)
        .padding(.vertical, 4)

        ForEach(byCategory) { item in
            HStack {
                Image(systemName: item.category.icon)
                    .foregroundStyle(item.category.color)
                    .frame(width: 24)
                Text(item.category.label)
                Spacer()
                Text(item.amount.currency).monospacedDigit()
                Text((item.amount / total).formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

struct ExpenseRowContent: View {
    let title: String
    let subtitle: String
    let amount: Double
    let category: ExpenseCategory

    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(category.color, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount.currency).monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

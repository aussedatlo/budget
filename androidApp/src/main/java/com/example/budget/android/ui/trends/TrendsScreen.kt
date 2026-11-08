package com.example.budget.android.ui.trends

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.budget.android.ui.BudgetCard
import com.example.budget.android.ui.Chip
import com.example.budget.android.ui.FormSection
import com.example.budget.android.ui.FormSheet
import com.example.budget.android.ui.LabeledRow
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.PillButton
import com.example.budget.android.ui.SectionTitle
import com.example.budget.android.ui.Sheet
import com.example.budget.android.ui.SnapshotButton
import com.example.budget.android.ui.TabScreen
import com.example.budget.android.ui.TappableCard
import com.example.budget.android.ui.charts.BarGroup
import com.example.budget.android.ui.charts.LineChart
import com.example.budget.android.ui.charts.Series
import com.example.budget.android.ui.charts.StackedBarChart
import com.example.budget.android.ui.currency
import com.example.budget.android.ui.monthName
import com.example.budget.android.ui.shortMonth
import com.example.budget.android.ui.signedCurrency
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetCalendar
import com.example.budget.core.BudgetState
import com.example.budget.core.charges.ChargeCategory
import com.example.budget.core.snapshots.Snapshot
import com.example.budget.core.snapshots.Trends
import com.example.budget.core.wealth.History
import com.example.budget.core.wealth.Savings
import com.example.budget.core.wealth.Wealth
import kotlin.time.Instant

/** How everything moved over time: net worth, investments, the monthly budget and savings. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TrendsScreen(state: BudgetState, nav: Nav) {
    val p = palette
    val points = Wealth.points(state.investments, state.loans, state.lendings)
    val netWorth = state.wealth.netWorth
    val snapshots = state.snapshots
    val takenThisMonth = Snapshot.isTakenThisMonth(snapshots)
    fun open(date: Instant) {
        snapshots.firstOrNull { BudgetCalendar.isSameMonth(it.date, date) }?.let { nav.present(Sheet.SnapshotDetail(it.id)) }
    }

    TabScreen("Trends", actions = { SnapshotButton(state, nav) }) {
        BudgetCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Column {
                    Text("Net worth", style = MaterialTheme.typography.bodyMedium, color = p.softInk)
                    Text(netWorth.currency, fontSize = 30.sp, fontWeight = FontWeight.Bold, color = p.ink,
                        modifier = Modifier.testTag("header-value"))
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    val first = points.firstOrNull()
                    if (first != null && points.size > 1) {
                        val change = netWorth - first.netWorth
                        Chip("${change.signedCurrency} since ${first.date.shortMonth()}", color = p.gain(change))
                    }
                    val last = snapshots.lastOrNull()
                    if (takenThisMonth && last != null) {
                        Chip("${last.date.monthName()} snapshot taken", color = p.positive, background = p.positive.copy(alpha = 0.12f))
                    } else if (last != null) {
                        Chip("Last snapshot ${last.date.monthName()}")
                    }
                }
                if (!takenThisMonth) {
                    Text(
                        "Once a month or so, update your charges, income and investments, then take the month's snapshot: it saves the whole picture and adds a point to these charts.",
                        style = MaterialTheme.typography.bodySmall, color = p.softInk,
                    )
                    Row { PillButton("Take a snapshot") { nav.present(Sheet.Snapshot) } }
                }
            }
        }

        if (points.isNotEmpty()) {
            ChartCard("Net worth over time") {
                LineChart(
                    listOfNotNull(
                        Series("Net worth", p.accent, points.map { it.date to it.netWorth }, filled = true),
                        Series("Investments", p.series[2], points.map { it.date to it.investments }),
                        if (state.loans.isNotEmpty()) Series("Home equity", p.series[3], points.map { it.date to it.homeEquity }) else null,
                        if (state.lendings.isNotEmpty()) Series("Money lent", p.lent, points.map { it.date to it.lent }) else null,
                    ),
                    onSelect = ::open,
                )
            }
        }
        if (state.investments.isNotEmpty()) {
            val history = History.points(state.investments)
            ChartCard("Investments") {
                if (history.size < 2) {
                    Text("Take a few snapshots to see the evolution.", color = p.softInk)
                } else {
                    LineChart(
                        listOf(
                            Series("Value", p.accent, history.map { it.date to it.value }, filled = true),
                            Series("Invested", p.softInk, history.map { it.date to it.invested }, dashed = true),
                        ),
                    )
                }
            }
            val saved = Savings.monthly(state.investments)
            ChartCard(
                "Saved per month",
                trailing = if (saved.isEmpty()) null else
                    "avg ${(saved.sumOf { it.amount } / saved.map { it.month }.distinct().size).currency}",
            ) {
                if (saved.isEmpty()) {
                    Text(
                        "Keep “invested so far” up to date to see how much you save each month. Market moves don't count, only the money you put in.",
                        color = p.softInk, style = MaterialTheme.typography.bodySmall,
                    )
                } else {
                    val names = saved.map { it.investment }.distinct()
                    StackedBarChart(
                        saved.groupBy { it.month }.map { (month, list) -> BarGroup(month, list.map { it.investment to it.amount }) },
                        names.mapIndexed { i, name -> name to p.series[i % p.series.size] }.toMap(),
                    )
                }
            }
        }
        ChartCard("Monthly budget", trailing = snapshots.lastOrNull()?.let { "left ${it.left.currency}" }) {
            if (snapshots.isEmpty()) {
                Text("No snapshot yet.", color = p.softInk)
            } else {
                StackedBarChart(
                    snapshots.map { BarGroup(it.date, listOf("Charges" to it.charges, "Savings" to it.savings, "Left" to it.left)) },
                    mapOf("Charges" to p.accent, "Savings" to p.series[1], "Left" to p.left),
                    onSelect = ::open,
                )
            }
        }
        ChartCard("Recurring charges", trailing = snapshots.lastOrNull()?.charges?.currency) {
            if (snapshots.isEmpty()) {
                Text("No snapshot yet.", color = p.softInk)
            } else {
                val colors = ChargeCategory.all.mapIndexed { i, c -> c.label to p.series[i % p.series.size] }.toMap()
                StackedBarChart(
                    snapshots.map { s ->
                        BarGroup(s.date, s.chargeLines.groupBy { ChargeCategory.fromRaw(it.category).label }
                            .map { (label, lines) -> label to lines.sumOf { it.amount } })
                    },
                    colors,
                    onSelect = ::open,
                )
            }
        }

        SectionTitle("Snapshots")
        val summaries = Trends.summaries(state)
        if (summaries.isEmpty()) {
            BudgetCard {
                Text(
                    "No snapshot yet. The first one starts the budget charts; the net worth already shows the values you recorded before.",
                    color = p.softInk, style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
        summaries.forEach { summary ->
            val snapshot = summary.snapshot
            TappableCard(
                onClick = { nav.present(Sheet.SnapshotDetail(snapshot.id)) },
                modifier = Modifier.testTag("snapshot-${snapshot.date.monthName()}"),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(snapshot.date.monthName(), style = MaterialTheme.typography.titleMedium, color = p.ink)
                        Text(
                            listOf("left ${snapshot.left.currency} a month", snapshot.note).filter { it.isNotEmpty() }.joinToString(" · "),
                            style = MaterialTheme.typography.bodySmall, color = p.softInk,
                        )
                    }
                    Spacer(Modifier.width(8.dp))
                    Column(horizontalAlignment = Alignment.End) {
                        Text(summary.wealth.netWorth.currency, style = MaterialTheme.typography.titleMedium, color = p.ink)
                        val change = summary.change
                        if (change != null && change != 0.0) {
                            Chip(change.signedCurrency, color = p.gain(change), background = p.gain(change).copy(alpha = 0.12f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ChartCard(title: String, trailing: String? = null, content: @Composable () -> Unit) {
    BudgetCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row {
                Text(title, style = MaterialTheme.typography.titleMedium, color = palette.ink, modifier = Modifier.weight(1f))
                if (trailing != null) Text(trailing, style = MaterialTheme.typography.bodySmall, color = palette.softInk)
            }
            content()
        }
    }
}

/** Everything a snapshot saved, as it was that month. */
@Composable
fun SnapshotDetailSheet(state: BudgetState, snapshot: Snapshot, nav: Nav) {
    val p = palette
    val wealth = Trends.summaries(state).firstOrNull { it.snapshot.id == snapshot.id }?.wealth
        ?: Wealth.pointAt(snapshot.endOfMonth, state.investments, state.loans, state.lendings)
    var asking by remember { mutableStateOf(false) }

    FormSheet(title = snapshot.date.monthName(), onDismiss = nav::dismiss, saveLabel = "Done", onSave = nav::dismiss, cancelLabel = null) {
        if (snapshot.note.isNotEmpty()) FormSection("Note") { Text(snapshot.note, color = p.ink) }
        FormSection("Monthly budget") {
            LabeledRow("Income", snapshot.income.currency)
            LabeledRow("Recurring charges", snapshot.charges.currency)
            LabeledRow("Savings", snapshot.savings.currency)
            LabeledRow("Left", snapshot.left.currency, if (snapshot.left >= 0) p.ink else p.negative)
        }
        FormSection("Net worth") {
            LabeledRow("Investments", wealth.investments.currency)
            if (state.loans.isNotEmpty()) LabeledRow("Home equity", wealth.homeEquity.currency)
            if (wealth.lent > 0) LabeledRow("Money lent", wealth.lent.currency)
            LabeledRow("Net worth", wealth.netWorth.currency)
        }
        if (snapshot.incomeLines.isNotEmpty()) {
            FormSection("Income") { snapshot.incomeLines.forEach { LabeledRow(it.title, it.amount.currency) } }
        }
        if (snapshot.chargeLines.isNotEmpty()) {
            FormSection("Recurring charges") { snapshot.chargeLines.forEach { LabeledRow(it.title, it.amount.currency) } }
        }
        TextButton(onClick = { asking = true }, modifier = Modifier.testTag("delete")) {
            Text("Delete this snapshot", color = p.negative)
        }
        Text("This can't be undone.", style = MaterialTheme.typography.bodySmall, color = p.softInk)
    }
    if (asking) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { asking = false },
            title = { Text("Delete the ${snapshot.date.monthName()} snapshot?") },
            text = {
                Text("The snapshot only: its budget goes, investments, the home loan and money lent keep what they were worth that month. With that month's values: those go too, including values you updated by hand that month.")
            },
            confirmButton = {
                Column(horizontalAlignment = Alignment.End) {
                    TextButton(onClick = {
                        asking = false; nav.dismiss(); nav.update { deleteSnapshot(snapshot.id, withValues = false) }
                    }) { Text("Delete the snapshot only", color = p.negative) }
                    TextButton(onClick = {
                        asking = false; nav.dismiss(); nav.update { deleteSnapshot(snapshot.id, withValues = true) }
                    }) { Text("Delete it and that month's values", color = p.negative) }
                    TextButton(onClick = { asking = false }) { Text("Cancel") }
                }
            },
        )
    }
}


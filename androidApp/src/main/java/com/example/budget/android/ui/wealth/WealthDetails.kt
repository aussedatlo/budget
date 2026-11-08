package com.example.budget.android.ui.wealth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.budget.android.ui.BackButton
import com.example.budget.android.ui.BudgetCard
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.PillButton
import com.example.budget.android.ui.SectionTitle
import com.example.budget.android.ui.Sheet
import com.example.budget.android.ui.StatTile
import com.example.budget.android.ui.TabScreen
import com.example.budget.android.ui.TappableCard
import com.example.budget.android.ui.charts.LineChart
import com.example.budget.android.ui.charts.Series
import com.example.budget.android.ui.currency
import com.example.budget.android.ui.dayText
import com.example.budget.android.ui.plain
import com.example.budget.android.ui.signedCurrency
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetState

@Composable
fun InvestmentDetailScreen(state: BudgetState, id: Long, nav: Nav) {
    val investment = state.investment(id)
    if (investment == null) {
        LaunchedEffect(id) { nav.back() }
        return
    }
    val p = palette
    TabScreen(
        investment.name,
        navigation = { BackButton(nav) },
        actions = { TextButton(onClick = { nav.present(Sheet.Investment(investment.id)) }) { Text("Edit") } },
    ) {
        BudgetCard {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                InvestmentRow(investment)
                Row {
                    StatTile("Invested", investment.investedAmount.currency, Modifier.weight(1f))
                    StatTile("Gain", investment.gain.signedCurrency, Modifier.weight(1f), color = p.gain(investment.gain))
                }
                if (investment.monthlyContribution > 0) {
                    Text("Savings plan: ${investment.monthlyContribution.currency} a month",
                        style = MaterialTheme.typography.bodySmall, color = p.softInk)
                }
            }
        }
        BudgetCard {
            val history = investment.history.sortedBy { it.date }
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
        SectionTitle("History")
        investment.sortedHistory.forEach { snapshot ->
            TappableCard(onClick = { nav.present(Sheet.Value(investment.id, snapshot.id)) }) {
                Column(Modifier.fillMaxWidth()) {
                    Row {
                        Text(snapshot.date.dayText(), color = p.ink, modifier = Modifier.weight(1f))
                        Text(snapshot.value.currency, style = MaterialTheme.typography.titleMedium, color = p.ink)
                    }
                    val units = if (snapshot.tracksUnits) "${snapshot.quantity!!.plain()} × ${snapshot.unitPrice!!.currency} · " else ""
                    Text("${units}invested ${snapshot.invested.currency}", style = MaterialTheme.typography.bodySmall, color = p.softInk)
                    if (snapshot.note.isNotEmpty()) Text(snapshot.note, style = MaterialTheme.typography.bodySmall, color = p.softInk)
                }
            }
        }
        Row { PillButton("Update values") { nav.present(Sheet.Value(investment.id, null)) } }
    }
}

@Composable
fun LoanDetailScreen(state: BudgetState, id: Long, nav: Nav) {
    val loan = state.loan(id)
    if (loan == null) {
        LaunchedEffect(id) { nav.back() }
        return
    }
    val p = palette
    TabScreen(
        loan.name,
        navigation = { BackButton(nav) },
        actions = { TextButton(onClick = { nav.present(Sheet.Loan(loan.id)) }) { Text("Edit") } },
    ) {
        LoanCard(loan)
        BudgetCard {
            val history = loan.history.sortedBy { it.date }
            if (history.size < 2) {
                Text("Take a snapshot from time to time to see the loan go down.", color = p.softInk)
            } else {
                LineChart(
                    listOf(
                        Series("Home value", p.series[2], history.map { it.date to it.homeValue }),
                        Series("Left to repay", p.accent, history.map { it.date to it.remaining }),
                    ),
                )
            }
        }
        SectionTitle("History")
        loan.sortedHistory.forEach { snapshot ->
            TappableCard(onClick = { nav.present(Sheet.LoanValue(loan.id, snapshot.id)) }) {
                Column(Modifier.fillMaxWidth()) {
                    Row {
                        Text(snapshot.date.dayText(), color = p.ink, modifier = Modifier.weight(1f))
                        Text(snapshot.remaining.currency, style = MaterialTheme.typography.titleMedium, color = p.ink)
                    }
                    Text("Home ${snapshot.homeValue.currency}", style = MaterialTheme.typography.bodySmall, color = p.softInk)
                }
            }
        }
        Row { PillButton("Update values") { nav.present(Sheet.LoanValue(loan.id, null)) } }
    }
}

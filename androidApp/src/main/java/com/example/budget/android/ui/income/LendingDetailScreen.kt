package com.example.budget.android.ui.income

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
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetState

@Composable
fun LendingDetailScreen(state: BudgetState, id: Long, nav: Nav) {
    val lending = state.lending(id)
    if (lending == null) {
        LaunchedEffect(id) { nav.back() }
        return
    }
    val p = palette
    TabScreen(
        lending.name,
        navigation = { BackButton(nav) },
        actions = { TextButton(onClick = { nav.present(Sheet.Lending(lending.id)) }) { Text("Edit") } },
    ) {
        LendingCard(lending)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            BudgetCard(Modifier.weight(1f), padding = 12.dp) { StatTile("Lent on", lending.date.dayText()) }
            BudgetCard(Modifier.weight(1f), padding = 12.dp) {
                StatTile("Monthly repayment", if (lending.monthlyRepayment > 0) lending.monthlyRepayment.currency else "–")
            }
        }
        BudgetCard {
            if (lending.history.isEmpty()) {
                Text("Update what's left from time to time to see it go down.", color = p.softInk)
            } else {
                val points = listOf(lending.date to lending.lent) + lending.history.sortedBy { it.date }.map { it.date to it.remaining }
                LineChart(listOf(Series("Left to repay", p.lent, points)))
            }
        }
        SectionTitle("History")
        lending.sortedHistory.forEach { snapshot ->
            TappableCard(onClick = { nav.present(Sheet.LendingValue(lending.id, snapshot.id)) }) {
                Column(Modifier.fillMaxWidth()) {
                    Row {
                        Text(snapshot.date.dayText(), color = p.ink, modifier = Modifier.weight(1f))
                        Text(snapshot.remaining.currency, style = MaterialTheme.typography.titleMedium, color = p.ink)
                    }
                    if (snapshot.note.isNotEmpty()) {
                        Text(snapshot.note, style = MaterialTheme.typography.bodySmall, color = p.softInk)
                    }
                }
            }
        }
        Row { PillButton("Update what's left") { nav.present(Sheet.LendingValue(lending.id, null)) } }
    }
}

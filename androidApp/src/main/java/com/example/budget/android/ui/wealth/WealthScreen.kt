package com.example.budget.android.ui.wealth

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.example.budget.android.ui.AddButton
import com.example.budget.android.ui.BarPart
import com.example.budget.android.ui.BudgetCard
import com.example.budget.android.ui.Chip
import com.example.budget.android.ui.CompositionBar
import com.example.budget.android.ui.ConfirmDelete
import com.example.budget.android.ui.EmojiBubble
import com.example.budget.android.ui.HintCard
import com.example.budget.android.ui.Mascot
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.ProgressBar
import com.example.budget.android.ui.Route
import com.example.budget.android.ui.SectionTitle
import com.example.budget.android.ui.Sheet
import com.example.budget.android.ui.SnapshotButton
import com.example.budget.android.ui.StatTile
import com.example.budget.android.ui.TabHeader
import com.example.budget.android.ui.TabScreen
import com.example.budget.android.ui.TappableCard
import com.example.budget.android.ui.currency
import com.example.budget.android.ui.percent
import com.example.budget.android.ui.signedCurrency
import com.example.budget.android.ui.signedPercent
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetState
import com.example.budget.core.Investment
import com.example.budget.core.Loan

/** What each position is worth, the home loan, and the net worth. */
@Composable
fun WealthScreen(state: BudgetState, nav: Nav) {
    val p = palette
    var deleting by remember { mutableStateOf<Investment?>(null) }
    /** Off: investments only. On: net worth, including the home, its loan and money lent. */
    var includeHome by rememberSaveable { mutableStateOf(false) }

    val investments = state.investments
    val value = investments.sumOf { it.currentValue }
    val invested = investments.sumOf { it.investedAmount }
    val gain = value - invested
    val homeEquity = state.loans.sumOf { it.equity }
    val owed = state.lendings.sumOf { it.remaining }
    val hasExtras = state.loans.isNotEmpty() || owed > 0
    val showsNetWorth = includeHome && hasExtras

    TabScreen(
        "Wealth",
        actions = {
            SnapshotButton(state, nav)
            AddButton(
                "Add investment" to { nav.present(Sheet.Investment(null)) },
                "Add home loan" to { nav.present(Sheet.Loan(null)) },
            )
        },
    ) {
        if (investments.isEmpty() && state.loans.isEmpty()) {
            HintCard(
                "No investments yet",
                "Add an ETF, gold coins, crypto, a savings account or your home loan, then update what it's worth from time to time.",
                "Add an investment" to { nav.present(Sheet.Investment(null)) },
                "Add home loan" to { nav.present(Sheet.Loan(null)) },
            )
            return@TabScreen
        }

        val parts = buildList {
            investments.filter { it.currentValue > 0 }.groupBy { it.kind }
                .mapValues { (_, list) -> list.sumOf { it.currentValue } }
                .entries.sortedByDescending { it.value }
                .forEach { (kind, amount) -> add(BarPart(kind.label, amount, p.bar(kind))) }
            if (showsNetWorth) {
                if (state.loans.isNotEmpty()) {
                    add(BarPart("Home equity", maxOf(homeEquity, 0.0), p.accent, shown = homeEquity, isWarning = homeEquity < 0))
                }
                if (owed > 0) add(BarPart("Money lent", owed, p.lent))
            }
        }
        TabHeader(
            title = if (showsNetWorth) "Net worth" else "Investments value",
            value = if (showsNetWorth) value + homeEquity + owed else value,
            bar = if (parts.isEmpty()) null else { { CompositionBar(parts) } },
            icon = { Mascot("🌱") },
            accessory = {
                if (hasExtras) {
                    FilterChip(
                        selected = includeHome,
                        onClick = { includeHome = !includeHome },
                        label = { Text("Net worth") },
                        modifier = Modifier.testTag("net-worth-toggle"),
                        colors = FilterChipDefaults.filterChipColors(selectedContainerColor = p.pink),
                    )
                }
            },
            caption = {
                if (investments.isNotEmpty()) {
                    Row {
                        Text("Invested ${invested.currency} · ", style = MaterialTheme.typography.bodySmall, color = p.softInk)
                        Text(
                            if (invested > 0) "${gain.signedCurrency} · ${(gain / invested).signedPercent()}" else gain.signedCurrency,
                            style = MaterialTheme.typography.bodySmall, color = p.gain(gain),
                        )
                    }
                }
            },
        )

        if (showsNetWorth && state.loans.isNotEmpty()) {
            SectionTitle("Home")
            state.loans.forEach { loan -> LoanCard(loan, Modifier.clickable { nav.open(Route.Loan(loan.id)) }) }
        }
        if (investments.isNotEmpty()) SectionTitle("Investments")
        investments.forEach { investment ->
            var menu by remember { mutableStateOf(false) }
            TappableCard(
                onClick = { nav.open(Route.Investment(investment.id)) },
                onLongClick = { menu = true },
                modifier = Modifier.testTag("investment-${investment.name}"),
            ) {
                InvestmentRow(investment)
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("Edit") }, onClick = { menu = false; nav.present(Sheet.Investment(investment.id)) })
                    DropdownMenuItem(text = { Text("Delete", color = p.negative) }, onClick = { menu = false; deleting = investment })
                }
            }
        }
    }

    deleting?.let { investment ->
        ConfirmDelete(
            "Delete ${investment.name}?", "Its whole history goes too.",
            onConfirm = { nav.update { deleteInvestment(investment.id) } },
            onDismiss = { deleting = null },
        )
    }
}

@Composable
fun InvestmentRow(investment: Investment) {
    val p = palette
    Row(verticalAlignment = Alignment.CenterVertically) {
        EmojiBubble(investment.displayEmoji, p.tint(investment.kind))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(investment.name, style = MaterialTheme.typography.titleMedium, color = p.ink)
            Text(
                listOf(investment.kind.label, investment.ticker).filter { it.isNotEmpty() }.joinToString(" · "),
                style = MaterialTheme.typography.bodySmall, color = p.softInk,
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(investment.currentValue.currency, style = MaterialTheme.typography.titleMedium, color = p.ink)
            if (investment.investedAmount > 0) {
                Chip(investment.gainRatio.signedPercent(), color = p.gain(investment.gain))
            }
        }
    }
}

/** Loan progress: what's repaid, and the part of the home that is ours. */
@Composable
fun LoanCard(loan: Loan, modifier: Modifier = Modifier) {
    val p = palette
    BudgetCard(modifier.testTag("loan-${loan.name}")) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                EmojiBubble(loan.emoji, p.peach)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(loan.name, style = MaterialTheme.typography.titleMedium, color = p.ink)
                    Text("${loan.equityRatio.percent()} equity", style = MaterialTheme.typography.bodySmall, color = p.softInk)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(loan.equity.currency, style = MaterialTheme.typography.titleMedium, color = p.ink)
                    Text("equity", style = MaterialTheme.typography.bodySmall, color = p.softInk)
                }
            }
            ProgressBar(loan.repaidRatio, p.accent)
            Row {
                StatTile("Repaid", loan.repaid.currency, Modifier.weight(1f), color = p.positive)
                StatTile("Left to repay", loan.remaining.currency, Modifier.weight(1f))
            }
        }
    }
}

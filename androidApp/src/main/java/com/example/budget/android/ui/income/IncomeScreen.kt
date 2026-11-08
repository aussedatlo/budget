package com.example.budget.android.ui.income

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.budget.android.ui.AddButton
import com.example.budget.android.ui.BarPart
import com.example.budget.android.ui.BudgetCard
import com.example.budget.android.ui.CompositionBar
import com.example.budget.android.ui.ConfirmDelete
import com.example.budget.android.ui.EmojiBubble
import com.example.budget.android.ui.HintCard
import com.example.budget.android.ui.ItemRow
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
import com.example.budget.android.ui.dayText
import com.example.budget.android.ui.monthName
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetCalendar
import com.example.budget.core.BudgetState
import com.example.budget.core.IncomeSource
import com.example.budget.core.Lending
import kotlin.time.Instant

/** Everything that comes in each month: income lines that can be switched on and off, and money lent being paid back. */
@Composable
fun IncomeScreen(state: BudgetState, nav: Nav) {
    val totals = state.incomeTotals
    val owed = state.lendings.sumOf { it.remaining }
    var deleting by remember { mutableStateOf<IncomeSource?>(null) }
    var showingRepaid by rememberSaveable { mutableStateOf(false) }
    val p = palette

    TabScreen(
        "Income",
        actions = {
            SnapshotButton(state, nav)
            AddButton(
                "Add income" to { nav.present(Sheet.IncomeSource(null)) },
                "Add money lent" to { nav.present(Sheet.Lending(null)) },
            )
        },
    ) {
        TabHeader(
            title = "Monthly income",
            value = totals.total,
            bar = if (totals.total > 0) {
                {
                    val counted = state.incomeSources.filter { it.isActive && it.amount > 0 }
                    val parts = counted.mapIndexed { i, source ->
                        BarPart(source.title, source.amount, p.incomeColors[i % p.incomeColors.size])
                    } + listOfNotNull(
                        if (totals.repayments > 0) BarPart("Money lent", totals.repayments, p.lent) else null,
                    )
                    CompositionBar(parts)
                }
            } else null,
            icon = { Mascot("💰") },
        )

        SectionTitle("Income", if (totals.sources > 0) totals.sources.currency else null)
        if (state.incomeSources.isEmpty()) {
            HintCard(
                "No income yet",
                "Add your salary and any other income, like freelance work or a bonus. Switch a line off in the months it doesn't come in.",
                "Add income" to { nav.present(Sheet.IncomeSource(null)) },
            )
        }
        state.incomeSources.forEach { source ->
            var menu by remember { mutableStateOf(false) }
            val last = lastCounted(state, source)
            val subtitle = buildString {
                append(if (source.isActive) "Counted this month" else "Not this month")
                if (last != null) append(" · last counted in ${last.monthName()}")
            }
            TappableCard(
                onClick = { nav.present(Sheet.IncomeSource(source.id)) },
                onLongClick = { menu = true },
                modifier = Modifier.testTag("income-${source.title}").alpha(if (source.isActive) 1f else 0.7f),
            ) {
                ItemRow(
                    source.emoji, p.mint, source.title, subtitle, source.amount.currency,
                    trailingColor = if (source.isActive) p.ink else p.softInk,
                    subtitleTag = "income-status-${source.title}",
                    struck = !source.isActive,
                )
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("Edit") }, onClick = { menu = false; nav.present(Sheet.IncomeSource(source.id)) })
                    DropdownMenuItem(text = { Text("Delete", color = p.negative) }, onClick = { menu = false; deleting = source })
                }
            }
        }

        SectionTitle("Money lent", if (owed > 0) "${owed.currency} owed" else null)
        if (state.lendings.isEmpty()) {
            HintCard(
                "No money lent",
                "Lent money to someone? Follow what they pay back. A monthly repayment counts as income until it's all repaid.",
                "Add money lent" to { nav.present(Sheet.Lending(null)) },
            )
        }
        state.lendings.filter { !it.isSettled }.forEach { lending ->
            LendingCard(lending, Modifier.clickable { nav.open(Route.Lending(lending.id)) })
        }
        val repaid = state.lendings.filter { it.isSettled }
        if (repaid.isNotEmpty()) {
            Row(
                Modifier.fillMaxWidth().clickable { showingRepaid = !showingRepaid }.padding(horizontal = 6.dp),
            ) {
                Text("Fully repaid (${repaid.size})", fontWeight = FontWeight.Bold, color = p.softInk, modifier = Modifier.weight(1f))
                Text(if (showingRepaid) "⌄" else "›", color = p.softInk)
            }
            if (showingRepaid) {
                repaid.forEach { lending ->
                    LendingCard(lending, Modifier.clickable { nav.open(Route.Lending(lending.id)) })
                }
            }
        }
    }

    deleting?.let { source ->
        ConfirmDelete("Delete ${source.title}?", onConfirm = { nav.update { deleteIncomeSource(source.id) } }, onDismiss = { deleting = null })
    }
}

/**
 * The month of the latest snapshot that counted this income, when it's not
 * the current month: a hint to switch it on or off for the new month.
 */
private fun lastCounted(state: BudgetState, source: IncomeSource): Instant? {
    val snapshot = state.snapshots.lastOrNull { snapshot -> snapshot.incomeLines.any { it.title == source.title } }
    val date = snapshot?.date ?: return null
    return if (BudgetCalendar.isSameMonth(date, BudgetCalendar.now())) null else date
}

/** Money lent and how much has come back. */
@Composable
fun LendingCard(lending: Lending, modifier: Modifier = Modifier) {
    val p = palette
    val subtitle = when {
        lending.isSettled -> "All repaid"
        lending.monthlyRepayment > 0 -> "${lending.monthlyRepayment.currency} a month"
        else -> "Since ${lending.date.dayText()}"
    }
    BudgetCard(modifier.testTag("lending-${lending.name}")) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                EmojiBubble(lending.emoji, p.sky)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(lending.name, style = MaterialTheme.typography.titleMedium, color = p.ink)
                    Text(subtitle, style = MaterialTheme.typography.bodySmall, color = p.softInk)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(lending.remaining.currency, style = MaterialTheme.typography.titleMedium,
                        color = if (lending.isSettled) p.positive else p.ink)
                    Text("left to repay", style = MaterialTheme.typography.bodySmall, color = p.softInk)
                }
            }
            ProgressBar(lending.repaidRatio, p.lent)
            Row {
                StatTile("Already repaid", lending.repaid.currency, Modifier.weight(1f), color = p.positive)
                StatTile("Lent", lending.lent.currency, Modifier.weight(1f))
            }
        }
    }
}

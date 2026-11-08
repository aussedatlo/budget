package com.example.budget.android.ui.budget

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.example.budget.android.ui.AddButton
import com.example.budget.android.ui.BarPart
import com.example.budget.android.ui.CompositionBar
import com.example.budget.android.ui.ConfirmDelete
import com.example.budget.android.ui.HintCard
import com.example.budget.android.ui.ItemRow
import com.example.budget.android.ui.Mascot
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.PillButton
import com.example.budget.android.ui.SectionTitle
import com.example.budget.android.ui.Sheet
import com.example.budget.android.ui.SnapshotButton
import com.example.budget.android.ui.Tab
import com.example.budget.android.ui.TabHeader
import com.example.budget.android.ui.TabScreen
import com.example.budget.android.ui.TappableCard
import com.example.budget.android.ui.LocalMoney
import com.example.budget.android.ui.currency
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetState
import com.example.budget.core.FixedCharge

/**
 * Monthly income (from the Income tab) minus recurring charges and planned
 * savings: what's left each month, next to a floating banknote.
 */
@Composable
fun BudgetScreen(state: BudgetState, nav: Nav) {
    val budget = state.budget
    var deleting by remember { mutableStateOf<FixedCharge?>(null) }
    val p = palette

    TabScreen(
        "Budget",
        navigation = {
            TextButton(onClick = { nav.present(Sheet.Settings) }, modifier = Modifier.semantics { contentDescription = "Settings" }) {
                Text("⚙️")
            }
        },
        actions = {
            SnapshotButton(state, nav)
            AddButton("Add charge" to { nav.present(Sheet.Charge(null)) })
        },
    ) {
        val left = budget.left
        TabHeader(
            title = budget.title,
            value = kotlin.math.abs(left),
            valueColor = if (left >= 0) p.ink else p.negative,
            bar = if (budget.income > 0 || budget.charges > 0) {
                {
                    CompositionBar(
                        listOf(
                            BarPart("Charges", budget.charges, p.accent),
                            BarPart("Savings", budget.savings, p.series[1]),
                            BarPart(if (left < 0) "Over" else "Left", maxOf(left, 0.0), p.left.copy(alpha = 0.35f),
                                shown = left, isWarning = left < 0),
                        ),
                        total = budget.income,
                    )
                }
            } else null,
            icon = { Mascot(banknote(LocalMoney.current.code), bounce = left > 0) },
            caption = {
                Text(
                    if (budget.income > 0) "of ${budget.income.currency} income ›" else "Add your income in the Income tab. ›",
                    style = MaterialTheme.typography.bodySmall,
                    color = p.softInk,
                    modifier = Modifier.testTag("open-income").clickable { nav.select(Tab.Income) },
                )
            },
        )

        SectionTitle("Recurring charges", budget.charges.currency)
        if (state.charges.isEmpty()) {
            HintCard(
                "No recurring charges yet",
                "Add rent, subscriptions, insurance and anything else paid every month.",
                "Add a charge" to { nav.present(Sheet.Charge(null)) },
            )
        }
        state.charges.forEach { charge ->
            var menu by remember { mutableStateOf(false) }
            TappableCard(
                onClick = { nav.present(Sheet.Charge(charge.id)) },
                onLongClick = { menu = true },
                modifier = Modifier.testTag("charge-${charge.title}"),
            ) {
                ItemRow(charge.displayEmoji, p.tint(charge.category), charge.title, charge.category.label, charge.amount.currency)
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("Edit") }, onClick = { menu = false; nav.present(Sheet.Charge(charge.id)) })
                    DropdownMenuItem(text = { Text("Delete", color = p.negative) }, onClick = { menu = false; deleting = charge })
                }
            }
        }

        SectionTitle("Monthly savings", if (budget.savings > 0) budget.savings.currency else null)
        state.savers.forEach { investment ->
            TappableCard(onClick = { nav.present(Sheet.SavingsPlan) }, modifier = Modifier.testTag("saver-${investment.name}")) {
                ItemRow(investment.displayEmoji, p.tint(investment.kind), investment.name, null, investment.monthlyContribution.currency)
            }
        }
        if (state.savers.isEmpty()) {
            HintCard(
                "No savings plan yet",
                "Set how much goes to each investment every month, e.g. 200 € to a savings account and 300 € to gold.",
                "Plan monthly savings" to { nav.present(Sheet.SavingsPlan) },
            )
        } else {
            Row { PillButton("Edit savings plan") { nav.present(Sheet.SavingsPlan) } }
        }
    }

    deleting?.let { charge ->
        ConfirmDelete("Delete ${charge.title}?", onConfirm = { nav.update { deleteCharge(charge.id) } }, onDismiss = { deleting = null })
    }
}

/** A banknote of the display currency. */
fun banknote(currency: String): String = when (currency) {
    "USD", "CAD", "AUD" -> "💵"
    "GBP" -> "💷"
    "JPY" -> "💴"
    else -> "💶"
}

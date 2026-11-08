package com.example.budget.android.ui.budget

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import com.example.budget.android.ui.AmountField
import com.example.budget.android.ui.FormSection
import com.example.budget.android.ui.FormSheet
import com.example.budget.android.ui.ItemRow
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.currency
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetState

/** How much goes to each investment every month. */
@Composable
fun SavingsPlanSheet(state: BudgetState, nav: Nav) {
    val amounts = remember { mutableStateMapOf<Long, Double?>() }
    val total = state.investments.sumOf { amounts[it.id] ?: it.monthlyContribution }

    FormSheet(
        title = "Savings plan",
        onDismiss = nav::dismiss,
        saveLabel = "Done",
        onSave = {
            val plan = amounts.mapValues { (_, amount) -> amount ?: 0.0 }
            if (plan.isNotEmpty()) nav.update { saveSavingsPlan(plan) }
            nav.dismiss()
        },
    ) {
        if (state.investments.isEmpty()) {
            Text(
                "Add an investment first (Wealth tab), then come back to plan your monthly savings.",
                color = palette.softInk,
            )
        } else {
            FormSection(
                title = "Every month · ${total.currency}",
                footer = "Set aside on the Budget screen, and added to “invested so far” in your next snapshot. You can always correct a month that was different.",
            ) {
                state.investments.forEach { investment ->
                    ItemRow(investment.displayEmoji, palette.tint(investment.kind), investment.name, null, "")
                    AmountField(
                        "Monthly savings",
                        if (investment.id in amounts) amounts[investment.id] else investment.monthlyContribution.takeIf { it > 0 },
                        { amounts[investment.id] = it },
                        tag = "plan-${investment.name}",
                    )
                }
            }
            Text("Leave empty for no saving.", style = MaterialTheme.typography.bodySmall, color = palette.softInk)
        }
    }
}

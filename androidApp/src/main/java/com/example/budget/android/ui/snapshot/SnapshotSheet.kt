package com.example.budget.android.ui.snapshot

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.example.budget.android.ui.AmountField
import com.example.budget.android.ui.FormSection
import com.example.budget.android.ui.FormSheet
import com.example.budget.android.ui.LabeledRow
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.StatTile
import com.example.budget.android.ui.TextInput
import com.example.budget.android.ui.currency
import com.example.budget.android.ui.dayText
import com.example.budget.android.ui.monthName
import com.example.budget.android.ui.signedCurrency
import com.example.budget.android.ui.theme.palette
import com.example.budget.android.ui.wealth.ValueDraft
import com.example.budget.android.ui.wealth.ValueFields
import com.example.budget.core.BudgetCalendar
import com.example.budget.core.BudgetState
import com.example.budget.core.Snapshot
import com.example.budget.core.data.SnapshotPlan
import com.example.budget.core.data.SnapshotRequest
import kotlin.math.abs

/**
 * The month's snapshot of everything at once, pre-filled with the current
 * values, to check them and fix what moved before saving. When months were
 * skipped since the last snapshot, it asks which one to do.
 */
@Composable
fun SnapshotSheet(state: BudgetState, nav: Nav) {
    val p = palette
    val now = remember { BudgetCalendar.now() }
    val currentMonth = remember { BudgetCalendar.startOfMonth(now) }
    val missing = remember { Snapshot.missingMonths(state.snapshots, now) }
    var month by remember { mutableStateOf(currentMonth) }
    var askingMonth by remember { mutableStateOf(missing.isNotEmpty()) }
    var pickingMonth by remember { mutableStateOf(false) }
    var confirmingDiscard by remember { mutableStateOf(false) }
    var note by remember { mutableStateOf("") }

    val sources = remember { mutableStateMapOf<Long, Pair<Double?, Boolean>>() }
    val charges = remember { mutableStateMapOf<Long, Double?>() }
    val values = remember { state.investments.associate { it.id to ValueDraft(it.latest, now) } }
    val loans = remember { mutableStateMapOf<Long, Pair<Double?, Double?>>() }
    val skippedRepayments = remember { mutableStateMapOf<Long, Boolean>() }
    val skippedSavings = remember { mutableStateMapOf<Long, Boolean>() }

    val request = SnapshotRequest(
        month = month,
        note = note,
        incomeSources = state.incomeSources.map { source ->
            val (amount, active) = sources[source.id] ?: (source.amount to source.isActive)
            SnapshotRequest.SourceEntry(source.id, amount ?: source.amount, active)
        },
        charges = state.charges.map { SnapshotRequest.ChargeEntry(it.id, charges[it.id] ?: it.amount) },
        investments = state.investments.mapNotNull { investment ->
            val draft = values.getValue(investment.id)
            if (!draft.isValid) null else SnapshotRequest.InvestmentEntry(
                investment.id, draft.computedValue,
                draft.quantity.takeIf { draft.tracksUnits }, draft.unitPrice.takeIf { draft.tracksUnits },
            )
        },
        loans = state.loans.mapNotNull { loan ->
            val (remaining, home) = loans[loan.id] ?: ((loan.latest?.remaining ?: loan.borrowed) to loan.latest?.homeValue)
            remaining?.let { SnapshotRequest.LoanEntry(loan.id, it, home ?: 0.0) }
        },
        skippedRepayments = skippedRepayments.filterValues { it }.keys,
        skippedSavings = skippedSavings.filterValues { it }.keys,
        now = now,
    )
    val plan = request.plan(state)
    val hasChanges = note.isNotEmpty() || sources.isNotEmpty() || charges.isNotEmpty() || loans.isNotEmpty() ||
        skippedRepayments.containsValue(true) || skippedSavings.containsValue(true) ||
        state.investments.any { inv ->
            val d = values.getValue(inv.id)
            val l = inv.latest
            d.tracksUnits != (l?.tracksUnits ?: false) || differs(d.value, l?.value) ||
                differs(d.quantity, l?.quantity) || differs(d.unitPrice, l?.unitPrice)
        }

    FormSheet(
        title = "Snapshot",
        onDismiss = { if (hasChanges) confirmingDiscard = true else nav.dismiss() },
        onSave = {
            nav.update { takeSnapshot(request) }
            nav.dismiss()
        },
    ) {
        FormSection(footer = summaryFooter(plan, month)) {
            Row {
                StatTile(if (plan.left >= 0) "Left each month" else "Over budget", abs(plan.left).currency, Modifier.weight(1f),
                    color = if (plan.left >= 0) p.ink else p.negative)
                StatTile("Net worth", plan.netWorth.currency, Modifier.weight(1f))
            }
            if (missing.isEmpty()) {
                LabeledRow("Month", month.monthName())
            } else {
                Box {
                    TextButton(onClick = { pickingMonth = true }, modifier = Modifier.fillMaxWidth().testTag("snapshot-month")) {
                        LabeledRow("Month", month.monthName(), p.accent)
                    }
                    DropdownMenu(expanded = pickingMonth, onDismissRequest = { pickingMonth = false }) {
                        (missing + currentMonth).forEach { option ->
                            DropdownMenuItem(text = { Text(option.monthName()) }, onClick = { month = option; pickingMonth = false })
                        }
                    }
                }
            }
            plan.replaces?.let {
                Text("Replaces the snapshot taken on ${it.date.dayText()}", style = MaterialTheme.typography.bodySmall, color = p.accent)
            }
            TextInput("Note", note, { note = it }, tag = "snapshot-note")
        }

        FormSection("Income · ${plan.income.currency}") {
            if (state.incomeSources.isEmpty()) Text("No income yet: add it in the Income tab.", color = p.softInk)
            state.incomeSources.forEach { source ->
                val (amount, active) = sources[source.id] ?: (source.amount to source.isActive)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Switch(
                        checked = active, onCheckedChange = { sources[source.id] = amount to it },
                        modifier = Modifier.testTag("snapshot-income-toggle-${source.title}"),
                        colors = SwitchDefaults.colors(checkedTrackColor = p.accent),
                    )
                    Spacer(Modifier.width(10.dp))
                    AmountField(source.title, amount, { sources[source.id] = it to active }, tag = "snapshot-income-${source.title}")
                }
            }
            plan.openLendings.filter { SnapshotPlan.repayment(it) > 0 }.forEach { lending ->
                SwitchLine(
                    "Repaid by ${lending.name}", SnapshotPlan.repayment(lending).currency,
                    on = skippedRepayments[lending.id] != true, tag = "snapshot-repayment-toggle-${lending.name}",
                ) { skippedRepayments[lending.id] = !it }
            }
        }

        val planned = state.savers
        if (planned.isNotEmpty()) {
            FormSection(
                "Monthly savings · ${plan.savings.currency}",
                footer = "Switch off what wasn't paid or saved this month. It only changes this snapshot.",
            ) {
                planned.forEach { investment ->
                    SwitchLine(
                        investment.name, investment.monthlyContribution.currency,
                        on = skippedSavings[investment.id] != true, tag = "snapshot-saving-toggle-${investment.name}",
                    ) { skippedSavings[investment.id] = !it }
                }
            }
        }

        if (state.charges.isNotEmpty()) {
            FormSection("Recurring charges · ${plan.charges.currency}") {
                state.charges.forEach { charge ->
                    AmountField("${charge.displayEmoji} ${charge.title}", charges[charge.id] ?: charge.amount,
                        { charges[charge.id] = it }, tag = "snapshot-charge-${charge.title}")
                }
            }
        }

        state.investments.forEach { investment ->
            FormSection(
                "${investment.displayEmoji} ${investment.name}",
                footer = investment.latest?.let { "Last recorded: ${it.value.currency} on ${it.date.dayText()}" },
            ) {
                ValueFields(values.getValue(investment.id), showsInvested = false)
            }
        }

        state.loans.forEach { loan ->
            val (remaining, home) = loans[loan.id] ?: ((loan.latest?.remaining ?: loan.borrowed) to loan.latest?.homeValue)
            FormSection(
                "${loan.emoji} ${loan.name}",
                footer = loan.latest?.let {
                    "Last recorded: ${it.remaining.currency} left to repay, home ${it.homeValue.currency} on ${it.date.dayText()}"
                },
            ) {
                AmountField("Left to repay", remaining, { loans[loan.id] = it to home }, tag = "loan-remaining")
                AmountField("Home value", home, { loans[loan.id] = remaining to it }, tag = "loan-home-value")
            }
        }
    }

    if (askingMonth) {
        AlertDialog(
            onDismissRequest = { askingMonth = false },
            title = {
                Text(if (missing.size == 1) "No snapshot for ${missing[0].monthName()}" else "No snapshot for ${missing.size} months")
            },
            text = {
                Text(
                    "Catch up on a missing month, or go for ${currentMonth.monthName()}? You can change it at the top of the snapshot." +
                        if (missing.size > 3) " Older months are listed there too." else "",
                )
            },
            confirmButton = {
                Column(horizontalAlignment = Alignment.End) {
                    missing.takeLast(3).forEach { missed ->
                        TextButton(onClick = { month = missed; askingMonth = false }) { Text(missed.monthName()) }
                    }
                    TextButton(onClick = { month = currentMonth; askingMonth = false }) { Text(currentMonth.monthName()) }
                }
            },
        )
    }
    if (confirmingDiscard) {
        AlertDialog(
            onDismissRequest = { confirmingDiscard = false },
            title = { Text("Discard your changes?") },
            text = { Text("Nothing in this snapshot is saved yet.") },
            confirmButton = {
                TextButton(onClick = { confirmingDiscard = false; nav.dismiss() }) { Text("Discard changes", color = p.negative) }
            },
            dismissButton = { TextButton(onClick = { confirmingDiscard = false }) { Text("Keep editing") } },
        )
    }
}

@Composable
private fun SwitchLine(title: String, amount: String, on: Boolean, tag: String, onChange: (Boolean) -> Unit) {
    val p = palette
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Switch(checked = on, onCheckedChange = onChange, modifier = Modifier.testTag(tag),
            colors = SwitchDefaults.colors(checkedTrackColor = p.accent))
        Text(title, color = if (on) p.ink else p.accent, modifier = Modifier.weight(1f))
        Text(amount, color = p.softInk, style = MaterialTheme.typography.bodyMedium.copy(
            textDecoration = if (on) null else TextDecoration.LineThrough))
    }
}

@Composable
private fun summaryFooter(plan: SnapshotPlan, month: kotlin.time.Instant): String {
    var text = "Everything is pre-filled with your current values. Check them, fix what moved, then save."
    if (!plan.isCurrentMonth) {
        text += " Investments and the home loan start from their latest values: set them to what they were in ${month.monthName()}."
        text += " Income and charges changed here are saved in this past month only: the tabs keep your current state."
    }
    val previous = plan.previous
    val before = plan.previousWealth
    if (previous != null && before != null) {
        text += "\n\nSince ${previous.date.monthName()}: net worth ${(plan.netWorth - before.netWorth).signedCurrency}, " +
            "left each month ${(plan.left - previous.left).signedCurrency}."
    }
    return text
}

private fun differs(a: Double?, b: Double?): Boolean = when {
    a == null && b == null -> false
    a != null && b != null -> abs(a - b) > 0.0005
    else -> true
}

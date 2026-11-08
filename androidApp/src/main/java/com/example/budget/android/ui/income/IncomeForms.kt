package com.example.budget.android.ui.income

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.example.budget.android.ui.AmountField
import com.example.budget.android.ui.DateField
import com.example.budget.android.ui.DeleteButton
import com.example.budget.android.ui.Emoji
import com.example.budget.android.ui.EmojiBubble
import com.example.budget.android.ui.EmojiPicker
import com.example.budget.android.ui.FormSection
import com.example.budget.android.ui.FormSheet
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.TextInput
import com.example.budget.android.ui.dayText
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetCalendar
import com.example.budget.core.IncomeSource
import com.example.budget.core.Lending
import com.example.budget.core.LendingSnapshot

@Composable
fun IncomeSourceForm(source: IncomeSource?, nav: Nav) {
    var title by remember { mutableStateOf(source?.title ?: "") }
    var amount by remember { mutableStateOf(source?.amount) }
    var emoji by remember { mutableStateOf(source?.emoji ?: "💼") }
    var isActive by remember { mutableStateOf(source?.isActive ?: true) }

    FormSheet(
        title = if (source == null) "New income" else "Edit income",
        onDismiss = nav::dismiss,
        canSave = title.isNotBlank() && (amount ?: 0.0) > 0,
        onSave = {
            val saved = (source ?: IncomeSource(title = "", amount = 0.0)).copy(
                title = title.trim(), amount = amount ?: 0.0, emoji = emoji.ifEmpty { "💼" }, isActive = isActive,
            )
            nav.update { saveIncomeSource(saved) }
            nav.dismiss()
        },
    ) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            EmojiBubble(emoji.ifEmpty { "💼" }, palette.mint, size = 72.dp)
        }
        FormSection(footer = "Switch it off in the months it doesn't come in: it stays listed but isn't counted.") {
            TextInput("Title (e.g. Freelance)", title, { title = it }, tag = "income-title")
            AmountField("Amount per month", amount, { amount = it }, tag = "income-amount")
            SwitchRow("Counted this month", isActive, tag = "income-active") { isActive = it }
        }
        FormSection("Icon") { EmojiPicker(emoji, Emoji.income) { emoji = it } }
        if (source != null) {
            DeleteButton("Delete this income", "Delete ${source.title}?") {
                nav.update { deleteIncomeSource(source.id) }
                nav.dismiss()
            }
        }
    }
}

@Composable
fun SwitchRow(label: String, checked: Boolean, tag: String, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, modifier = Modifier.weight(1f), color = palette.ink)
        Switch(
            checked = checked, onCheckedChange = onChange, modifier = Modifier.testTag(tag),
            colors = SwitchDefaults.colors(checkedTrackColor = palette.accent),
        )
    }
}

@Composable
fun LendingForm(lending: Lending?, nav: Nav) {
    var name by remember { mutableStateOf(lending?.name ?: "") }
    var lent by remember { mutableStateOf(lending?.lent) }
    var date by remember { mutableStateOf(lending?.date ?: BudgetCalendar.now()) }
    var monthly by remember { mutableStateOf(lending?.monthlyRepayment?.takeIf { it > 0 }) }
    var emoji by remember { mutableStateOf(lending?.emoji ?: "💸") }
    val latest = lending?.latest
    var remaining by remember { mutableStateOf(latest?.remaining) }

    FormSheet(
        title = if (lending == null) "New money lent" else "Edit money lent",
        onDismiss = nav::dismiss,
        canSave = name.isNotBlank() && (lent ?: 0.0) > 0,
        onSave = {
            val saved = (lending ?: Lending(name = "", lent = 0.0)).copy(
                name = name.trim(), emoji = emoji.ifEmpty { "💸" }, lent = lent ?: 0.0, date = date,
                monthlyRepayment = maxOf(monthly ?: 0.0, 0.0),
            )
            nav.update {
                saveLending(saved)
                val value = remaining
                if (latest != null && value != null) {
                    saveLendingSnapshot(saved.id, latest.copy(remaining = maxOf(value, 0.0)))
                }
            }
            nav.dismiss()
        },
    ) {
        FormSection {
            TextInput("Lent to (e.g. Lucas)", name, { name = it }, tag = "lending-name")
            AmountField("Amount lent", lent, { lent = it }, tag = "lending-amount")
            DateField("Lent on", date, { date = it })
        }
        if (latest != null) {
            FormSection(
                title = "Current value · ${latest.date.dayText()}",
                footer = "Corrects the value of that day. To keep the history, use “Update what's left” on the loan page or take a snapshot instead.",
            ) {
                AmountField("Left to repay", remaining, { remaining = it }, tag = "lending-remaining")
            }
        }
        FormSection(footer = "Optional. Counted as income each month until it's all repaid. Update what's left from time to time.") {
            AmountField("Monthly repayment", monthly, { monthly = it }, tag = "lending-monthly")
        }
        FormSection("Icon") { EmojiPicker(emoji, Emoji.people) { emoji = it } }
        if (lending != null) {
            DeleteButton("Delete this loan", "Delete ${lending.name}?") {
                nav.update { deleteLending(lending.id) }
                nav.dismiss()
                nav.back()
            }
        }
    }
}

/** What's left to repay at a date: a new value, or one from the history. */
@Composable
fun LendingValueForm(lending: Lending, snapshotId: Long?, nav: Nav) {
    val snapshot = lending.history.firstOrNull { it.id == snapshotId }
    var date by remember { mutableStateOf(snapshot?.date ?: BudgetCalendar.now()) }
    var remaining by remember { mutableStateOf(snapshot?.remaining ?: lending.remaining) }
    var note by remember { mutableStateOf(snapshot?.note ?: "") }

    FormSheet(
        title = if (snapshot == null) "Update what's left" else "Edit past value",
        onDismiss = nav::dismiss,
        canSave = remaining != null,
        onSave = {
            val existing = snapshot ?: lending.entryOn(date)
            val saved = (existing ?: LendingSnapshot()).copy(date = date, remaining = maxOf(remaining ?: 0.0, 0.0), note = note)
            nav.update { saveLendingSnapshot(lending.id, saved) }
            nav.dismiss()
        },
    ) {
        FormSection(footer = if (snapshot == null) "Pre-filled with what was left last time: just change it." else null) {
            DateField("Date", date, { date = it })
            AmountField("Left to repay", remaining, { remaining = it }, tag = "lending-remaining")
            TextInput("Note", note, { note = it }, tag = "note")
        }
        if (snapshot != null) {
            DeleteButton("Delete this value", "Delete this value?") {
                nav.update { deleteLendingSnapshot(snapshot.id) }
                nav.dismiss()
            }
        }
    }
}

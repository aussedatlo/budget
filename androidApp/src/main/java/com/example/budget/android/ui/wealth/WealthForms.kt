package com.example.budget.android.ui.wealth

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
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
import com.example.budget.android.ui.LabeledRow
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.TextInput
import com.example.budget.android.ui.currency
import com.example.budget.android.ui.dayText
import com.example.budget.android.ui.income.SwitchRow
import com.example.budget.android.ui.signedCurrency
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetCalendar
import com.example.budget.core.wealth.Investment
import com.example.budget.core.wealth.InvestmentKind
import com.example.budget.core.wealth.Loan
import com.example.budget.core.wealth.LoanSnapshot
import com.example.budget.core.wealth.ValueSnapshot
import kotlin.time.Instant

/** What a position is worth at a date, as typed in a form. */
class ValueDraft(from: ValueSnapshot?, var date: Instant = BudgetCalendar.now()) {
    var tracksUnits by mutableStateOf(from?.tracksUnits ?: false)
    var quantity by mutableStateOf(from?.quantity)
    var unitPrice by mutableStateOf(from?.unitPrice)
    var value by mutableStateOf(from?.value)
    var invested by mutableStateOf(from?.invested)

    val computedValue: Double get() = if (tracksUnits) (quantity ?: 0.0) * (unitPrice ?: 0.0) else value ?: 0.0
    val isValid: Boolean get() = if (tracksUnits) quantity != null && unitPrice != null else value != null

    fun toSnapshot(id: Long = 0, note: String = "") = ValueSnapshot(
        id = id, date = date, value = computedValue, invested = invested ?: 0.0,
        quantity = if (tracksUnits) quantity else null, unitPrice = if (tracksUnits) unitPrice else null, note = note,
    )
}

@Composable
fun ValueFields(draft: ValueDraft, showsInvested: Boolean = true, plannedAddition: Double = 0.0) {
    SwitchRow("Quantity × unit price", draft.tracksUnits, tag = "snapshot-units") { draft.tracksUnits = it }
    if (draft.tracksUnits) {
        AmountField("Quantity", draft.quantity, { draft.quantity = it }, tag = "snapshot-quantity")
        AmountField("Unit price", draft.unitPrice, { draft.unitPrice = it }, tag = "snapshot-unit-price")
        LabeledRow("Value", draft.computedValue.currency)
    } else {
        AmountField("Value", draft.value, { draft.value = it }, tag = "snapshot-value")
    }
    if (showsInvested) {
        AmountField("Invested so far", draft.invested, { draft.invested = it }, tag = "snapshot-invested")
        if (plannedAddition > 0) {
            Text(
                "Includes ${plannedAddition.signedCurrency} from the savings plan. Change it if this month was different.",
                style = MaterialTheme.typography.bodySmall, color = palette.softInk,
            )
        }
    }
}

@Composable
fun InvestmentForm(investment: Investment?, nav: Nav) {
    var name by remember { mutableStateOf(investment?.name ?: "") }
    var ticker by remember { mutableStateOf(investment?.ticker ?: "") }
    var kind by remember { mutableStateOf(investment?.kind ?: InvestmentKind.ETF) }
    var emoji by remember { mutableStateOf(investment?.displayEmoji ?: InvestmentKind.ETF.emoji) }
    var monthly by remember { mutableStateOf(investment?.monthlyContribution?.takeIf { it > 0 }) }
    val draft = remember { ValueDraft(null) }
    var picking by remember { mutableStateOf(false) }

    FormSheet(
        title = if (investment == null) "New investment" else "Edit investment",
        onDismiss = nav::dismiss,
        canSave = name.isNotBlank() && (investment != null || draft.isValid),
        onSave = {
            val saved = (investment ?: Investment(name = "")).copy(
                name = name.trim(), ticker = ticker.trim(), kind = kind,
                emoji = if (emoji == kind.emoji) "" else emoji,
                monthlyContribution = maxOf(monthly ?: 0.0, 0.0),
                history = if (investment == null) listOf(draft.toSnapshot()) else investment.history,
            )
            nav.update { saveInvestment(saved) }
            nav.dismiss()
        },
    ) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            EmojiBubble(emoji.ifEmpty { kind.emoji }, palette.tint(kind), size = 72.dp)
        }
        FormSection {
            TextInput("Name (e.g. MSCI World)", name, { name = it }, tag = "investment-name")
            TextInput("Ticker (optional)", ticker, { ticker = it }, tag = "investment-ticker")
            Box {
                TextButton(onClick = { picking = true }, modifier = Modifier.fillMaxWidth().testTag("investment-kind")) {
                    LabeledRow("Type", kind.label, palette.accent)
                }
                DropdownMenu(expanded = picking, onDismissRequest = { picking = false }) {
                    InvestmentKind.all.forEach { option ->
                        DropdownMenuItem(text = { Text(option.label) }, onClick = {
                            if (emoji == kind.emoji) emoji = option.emoji
                            kind = option
                            picking = false
                        })
                    }
                }
            }
        }
        FormSection(
            title = "Savings plan",
            footer = "How much you usually add every month. It's added to “invested so far” for you when you update the values, and it's set aside on the Budget screen.",
        ) {
            AmountField("Monthly savings", monthly, { monthly = it }, tag = "monthly-contribution")
        }
        if (investment == null) {
            FormSection(title = "Today", footer = "What it's worth now and how much you put in so far. You can update it any time.") {
                ValueFields(draft)
            }
        }
        FormSection("Icon") { EmojiPicker(emoji, Emoji.investments) { emoji = it } }
        if (investment != null) {
            DeleteButton("Delete this investment", "Delete ${investment.name}?") {
                nav.update { deleteInvestment(investment.id) }
                nav.dismiss()
                nav.back()
            }
        }
    }
}

/** New values for a position, or a past value fixed. */
@Composable
fun ValueForm(investment: Investment, snapshotId: Long?, nav: Nav) {
    val snapshot = investment.history.firstOrNull { it.id == snapshotId }
    val now = remember { BudgetCalendar.now() }
    val draft = remember {
        if (snapshot != null) {
            ValueDraft(snapshot, snapshot.date)
        } else {
            ValueDraft(investment.latest, now).also { d ->
                investment.latest?.let { latest ->
                    if (investment.monthlyContribution > 0) {
                        d.invested = latest.invested +
                            investment.monthlyContribution * BudgetCalendar.monthsBetween(latest.date, now)
                    }
                }
            }
        }
    }
    var date by remember { mutableStateOf(draft.date) }
    var note by remember { mutableStateOf(snapshot?.note ?: "") }
    val planned = if (snapshot == null && investment.monthlyContribution > 0) {
        investment.latest?.let { investment.monthlyContribution * BudgetCalendar.monthsBetween(it.date, date) } ?: 0.0
    } else 0.0

    FormSheet(
        title = if (snapshot == null) "Update values" else "Edit past values",
        onDismiss = nav::dismiss,
        canSave = draft.isValid,
        onSave = {
            draft.date = date
            val existing = snapshot ?: investment.entryOn(date)
            val saved = draft.toSnapshot(existing?.id ?: 0, note)
            nav.update { saveValueSnapshot(investment.id, saved) }
            nav.dismiss()
        },
    ) {
        FormSection(footer = if (snapshot == null) "Pre-filled with the current values: just change what moved." else null) {
            DateField("Date", date, { date = it })
            ValueFields(draft, plannedAddition = planned)
            TextInput("Note", note, { note = it }, tag = "note")
        }
        if (snapshot != null) {
            DeleteButton("Delete these values", "Delete these values?") {
                nav.update { deleteValueSnapshot(snapshot.id) }
                nav.dismiss()
            }
        }
    }
}

@Composable
fun LoanForm(loan: Loan?, nav: Nav) {
    var name by remember { mutableStateOf(loan?.name ?: "Home") }
    var borrowed by remember { mutableStateOf(loan?.borrowed) }
    var emoji by remember { mutableStateOf(loan?.emoji ?: "🏠") }
    val latest = loan?.latest
    var remaining by remember { mutableStateOf(latest?.remaining) }
    var homeValue by remember { mutableStateOf(latest?.homeValue) }

    FormSheet(
        title = if (loan == null) "New home loan" else "Edit loan",
        onDismiss = nav::dismiss,
        canSave = name.isNotBlank() && (borrowed ?: 0.0) > 0 && (loan != null || remaining != null),
        onSave = {
            val saved = (loan ?: Loan(name = "", borrowed = 0.0)).copy(
                name = name.trim(), emoji = emoji.ifEmpty { "🏠" }, borrowed = borrowed ?: 0.0,
                history = if (loan == null) {
                    listOf(LoanSnapshot(remaining = remaining ?: borrowed ?: 0.0, homeValue = homeValue ?: 0.0))
                } else loan.history,
            )
            nav.update {
                saveLoan(saved)
                if (latest != null) {
                    saveLoanSnapshot(saved.id, latest.copy(remaining = remaining ?: latest.remaining, homeValue = homeValue ?: latest.homeValue))
                }
            }
            nav.dismiss()
        },
    ) {
        FormSection {
            TextInput("Name", name, { name = it }, tag = "loan-name")
            AmountField("Amount borrowed", borrowed, { borrowed = it }, tag = "loan-borrowed")
        }
        FormSection(
            title = if (latest != null) "Current values · ${latest.date.dayText()}" else "Today",
            footer = if (latest != null) {
                "Corrects the values of that day. To keep the history, use “Update values” on the loan page or take a snapshot instead."
            } else {
                "“Left to repay” is on your bank statement. The home value is your best estimate; you can update both any time."
            },
        ) {
            AmountField("Left to repay", remaining, { remaining = it }, tag = "loan-remaining")
            AmountField("Home value", homeValue, { homeValue = it }, tag = "loan-home-value")
        }
        FormSection("Icon") { EmojiPicker(emoji, Emoji.homes) { emoji = it } }
        if (loan != null) {
            DeleteButton("Delete this loan", "Delete ${loan.name}?") {
                nav.update { deleteLoan(loan.id) }
                nav.dismiss()
                nav.back()
            }
        }
    }
}

@Composable
fun LoanValueForm(loan: Loan, snapshotId: Long?, nav: Nav) {
    val snapshot = loan.history.firstOrNull { it.id == snapshotId }
    val base = snapshot ?: loan.latest
    var date by remember { mutableStateOf(snapshot?.date ?: BudgetCalendar.now()) }
    var remaining by remember { mutableStateOf<Double?>(base?.remaining ?: loan.borrowed) }
    var homeValue by remember { mutableStateOf(base?.homeValue) }
    var note by remember { mutableStateOf(snapshot?.note ?: "") }

    FormSheet(
        title = if (snapshot == null) "Update values" else "Edit past values",
        onDismiss = nav::dismiss,
        canSave = remaining != null,
        onSave = {
            val existing = snapshot ?: loan.entryOn(date)
            val saved = LoanSnapshot(existing?.id ?: 0, date, remaining ?: 0.0, homeValue ?: 0.0, note)
            nav.update { saveLoanSnapshot(loan.id, saved) }
            nav.dismiss()
        },
    ) {
        FormSection(footer = if (snapshot == null) "Pre-filled with the current values: just change what moved." else null) {
            DateField("Date", date, { date = it })
            AmountField("Left to repay", remaining, { remaining = it }, tag = "loan-remaining")
            AmountField("Home value", homeValue, { homeValue = it }, tag = "loan-home-value")
            TextInput("Note", note, { note = it }, tag = "note")
        }
        if (snapshot != null) {
            DeleteButton("Delete these values", "Delete these values?") {
                nav.update { deleteLoanSnapshot(snapshot.id) }
                nav.dismiss()
            }
        }
    }
}

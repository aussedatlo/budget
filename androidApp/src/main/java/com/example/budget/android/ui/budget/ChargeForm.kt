package com.example.budget.android.ui.budget

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import com.example.budget.android.ui.DeleteButton
import com.example.budget.android.ui.Emoji
import com.example.budget.android.ui.EmojiBubble
import com.example.budget.android.ui.EmojiPicker
import com.example.budget.android.ui.FormSection
import com.example.budget.android.ui.FormSheet
import com.example.budget.android.ui.LabeledRow
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.TextInput
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.charges.ChargeCategory
import com.example.budget.core.charges.FixedCharge

@Composable
fun ChargeForm(charge: FixedCharge?, nav: Nav) {
    var title by remember { mutableStateOf(charge?.title ?: "") }
    var amount by remember { mutableStateOf(charge?.amount) }
    var category by remember { mutableStateOf(charge?.category ?: ChargeCategory.HOUSING) }
    var emoji by remember { mutableStateOf(charge?.displayEmoji ?: ChargeCategory.HOUSING.emoji) }
    var picking by remember { mutableStateOf(false) }

    FormSheet(
        title = if (charge == null) "New charge" else "Edit charge",
        onDismiss = nav::dismiss,
        canSave = title.isNotBlank() && (amount ?: 0.0) > 0,
        onSave = {
            val saved = (charge ?: FixedCharge(title = "", amount = 0.0)).copy(
                title = title.trim(),
                amount = amount ?: 0.0,
                category = category,
                emoji = if (emoji == category.emoji) "" else emoji,
            )
            nav.update { saveCharge(saved) }
            nav.dismiss()
        },
    ) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            EmojiBubble(emoji.ifEmpty { category.emoji }, palette.tint(category), size = 72.dp)
        }
        FormSection {
            TextInput("Title (e.g. Rent)", title, { title = it }, tag = "charge-title")
            AmountField("Amount", amount, { amount = it }, tag = "charge-amount")
            Box {
                TextButton(onClick = { picking = true }, modifier = Modifier.fillMaxWidth().testTag("charge-category")) {
                    LabeledRow("Category", category.label, palette.accent)
                }
                DropdownMenu(expanded = picking, onDismissRequest = { picking = false }) {
                    ChargeCategory.all.forEach { option ->
                        DropdownMenuItem(text = { Text(option.label) }, onClick = {
                            // Follow the category until a custom emoji is picked
                            if (emoji == category.emoji) emoji = option.emoji
                            category = option
                            picking = false
                        })
                    }
                }
            }
        }
        FormSection("Icon") {
            EmojiPicker(emoji, Emoji.charges) { emoji = it }
        }
        if (charge != null) {
            DeleteButton("Delete this charge", "Delete ${charge.title}?") {
                nav.update { deleteCharge(charge.id) }
                nav.dismiss()
            }
        }
    }
}

package com.example.budget.android.ui.settings

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.example.budget.android.BuildConfig
import com.example.budget.android.ui.FormSection
import com.example.budget.android.ui.FormSheet
import com.example.budget.android.ui.LabeledRow
import com.example.budget.android.ui.Nav
import com.example.budget.android.ui.theme.palette

@Composable
fun SettingsSheet(currency: String, setCurrency: (String) -> Unit, nav: Nav) {
    val currencies = (listOf("EUR", "USD", "GBP", "CHF", "CAD", "JPY", "AUD") + currency).distinct().sorted()
    val context = LocalContext.current
    FormSheet(title = "Settings", onDismiss = nav::dismiss, saveLabel = "Done", onSave = nav::dismiss, cancelLabel = null) {
        FormSection("Currency") {
            currencies.forEach { code ->
                Row(
                    Modifier.fillMaxWidth().clickable { setCurrency(code) }.testTag("currency-$code"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(selected = code == currency, onClick = { setCurrency(code) },
                        colors = RadioButtonDefaults.colors(selectedColor = palette.accent))
                    Text(code, color = palette.ink)
                }
            }
        }
        FormSection {
            LabeledRow("Version", "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
        }
        Text(
            "Icons and emoji ideas from OpenMoji, licensed under CC BY-SA 4.0.",
            style = MaterialTheme.typography.bodySmall,
            color = palette.softInk,
            modifier = Modifier.padding(horizontal = 6.dp).clickable {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://openmoji.org")))
            },
        )
    }
}

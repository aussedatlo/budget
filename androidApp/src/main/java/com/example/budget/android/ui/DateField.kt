package com.example.budget.android.ui

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetCalendar
import kotlin.time.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.toInstant
import kotlinx.datetime.toLocalDateTime

/** A date, picked in a calendar. The time of day is kept. */
@Composable
fun DateField(label: String, value: Instant, onChange: (Instant) -> Unit, tag: String = "date") {
    var open by remember { mutableStateOf(false) }
    TextButton(onClick = { open = true }, modifier = Modifier.fillMaxWidth().testTag(tag)) {
        LabeledRow(label, value.dayText(), palette.accent)
    }
    if (open) {
        // The picker works in UTC days
        val day = value.toLocalDateTime(BudgetCalendar.timeZone).date
        val picker = rememberDatePickerState(initialSelectedDateMillis = day.atStartOfDayIn(TimeZone.UTC).toEpochMilliseconds())
        DatePickerDialog(
            onDismissRequest = { open = false },
            confirmButton = {
                TextButton(onClick = {
                    picker.selectedDateMillis?.let { millis ->
                        val picked = Instant.fromEpochMilliseconds(millis).toLocalDateTime(TimeZone.UTC).date
                        onChange(moveToDay(value, picked))
                    }
                    open = false
                }) { Text("OK") }
            },
            dismissButton = { TextButton(onClick = { open = false }) { Text("Cancel") } },
        ) { DatePicker(picker) }
    }
}

private fun moveToDay(instant: Instant, day: LocalDate): Instant {
    val tz = BudgetCalendar.timeZone
    val time = instant.toLocalDateTime(tz).time
    return LocalDateTime(day, time).toInstant(tz)
}

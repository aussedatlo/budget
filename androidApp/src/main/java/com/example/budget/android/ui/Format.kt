package com.example.budget.android.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import com.example.budget.core.BudgetCalendar
import java.text.NumberFormat
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Currency
import java.util.Locale
import kotlin.math.abs
import kotlin.time.Instant

/** Formats amounts in the display currency. */
class Money(val code: String, private val locale: Locale = Locale.getDefault()) {
    private val format = NumberFormat.getCurrencyInstance(locale).apply {
        currency = runCatching { Currency.getInstance(code) }.getOrDefault(Currency.getInstance("EUR"))
    }

    fun format(value: Double): String = synchronized(format) { format.format(value) }

    /** Always with its sign, e.g. "+120,00 €". */
    fun signed(value: Double): String = (if (value >= 0) "+" else "−") + format(abs(value))
}

val LocalMoney = compositionLocalOf { Money("EUR") }

val Double.currency: String
    @Composable get() = LocalMoney.current.format(this)

val Double.signedCurrency: String
    @Composable get() = LocalMoney.current.signed(this)

/** "+4.25 %" */
fun Double.signedPercent(): String = String.format(Locale.getDefault(), "%+.2f %%", this * 100)

/** "37 %" */
fun Double.percent(): String = String.format(Locale.getDefault(), "%.0f %%", this * 100)

/** Short form for chart axes, e.g. "12K". */
fun Double.compact(): String {
    val v = abs(this)
    val sign = if (this < 0) "-" else ""
    return when {
        v >= 1_000_000 -> sign + trim(v / 1_000_000) + "M"
        v >= 1_000 -> sign + trim(v / 1_000) + "K"
        else -> sign + trim(v)
    }
}

private fun trim(v: Double): String =
    if (v >= 100 || v == Math.floor(v)) v.toInt().toString() else String.format(Locale.getDefault(), "%.1f", v)

/** A number as typed back in a field: no grouping, no trailing zeros. */
fun Double.plain(): String {
    if (this == Math.floor(this) && abs(this) < 1e15) return toLong().toString()
    return java.math.BigDecimal(this).setScale(6, java.math.RoundingMode.HALF_UP).stripTrailingZeros().toPlainString()
}

/** Reads a typed number, with a dot or a comma. */
fun parseAmount(text: String): Double? = text.trim().replace(" ", "").replace(' ', ' ').replace(" ", "")
    .replace(',', '.').toDoubleOrNull()

private fun local(instant: Instant) =
    java.time.Instant.ofEpochMilli(instant.toEpochMilliseconds()).atZone(ZoneId.of(BudgetCalendar.timeZone.id))

/** "October 2026" */
fun Instant.monthName(): String = local(this).format(DateTimeFormatter.ofPattern("LLLL yyyy", Locale.getDefault()))
    .replaceFirstChar { it.titlecase(Locale.getDefault()) }

/** "Oct 2026" */
fun Instant.shortMonth(): String = local(this).format(DateTimeFormatter.ofPattern("LLL yy", Locale.getDefault()))

/** "8 Oct 2026" */
fun Instant.dayText(): String = local(this).format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))

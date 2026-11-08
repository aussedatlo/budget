package com.example.budget.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import com.example.budget.core.ChargeCategory
import com.example.budget.core.InvestmentKind
import com.example.budget.core.Tint

/**
 * The calm palette of the iOS app: neutral background, white cards, one
 * dusty-rose accent and very light tints behind icons.
 */
@Immutable
data class Palette(
    val background: Color,
    val card: Color,
    val ink: Color,
    val softInk: Color,
    val accent: Color,
    val pink: Color,
    val peach: Color,
    val mint: Color,
    val lavender: Color,
    val butter: Color,
    val sky: Color,
    /** Distinct, muted colors for chart series. */
    val series: List<Color>,
    val positive: Color,
    val negative: Color,
    val crypto: Color,
    val savingsBar: Color,
    val realEstate: Color,
    val otherBar: Color,
) {
    /** What's left of the month, in the income bar. */
    val left: Color get() = series[2]
    /** Money lent to others: a calm blue, apart from the home loan's rose. */
    val lent: Color get() = series[1]
    /** Income lines in the Income bar: the chart colors without money lent's blue. */
    val incomeColors: List<Color> get() = listOf(series[0], series[2], series[3], series[4], series[5])

    fun tint(tint: Tint): Color = when (tint) {
        Tint.PINK -> pink
        Tint.PEACH -> peach
        Tint.MINT -> mint
        Tint.LAVENDER -> lavender
        Tint.BUTTER -> butter
        Tint.SKY -> sky
    }

    fun tint(category: ChargeCategory): Color = tint(category.tint)
    fun tint(kind: InvestmentKind): Color = tint(kind.tint)

    /** A kind's part of the Wealth bar. */
    fun bar(kind: InvestmentKind): Color = when (kind) {
        InvestmentKind.STOCK -> series[4]
        InvestmentKind.ETF -> series[2]
        InvestmentKind.FUND -> series[5]
        InvestmentKind.CRYPTO -> crypto
        InvestmentKind.METAL -> series[3]
        InvestmentKind.SAVINGS -> savingsBar
        InvestmentKind.REAL_ESTATE -> realEstate
        InvestmentKind.OTHER -> otherBar
    }

    fun gain(value: Double): Color = when {
        value > 0 -> positive
        value < 0 -> negative
        else -> softInk
    }
}

private fun hex(value: Long) = Color(0xFF000000 or value)

val LightPalette = Palette(
    background = hex(0xF6F5F2), card = hex(0xFFFFFF), ink = hex(0x2A2830), softInk = hex(0x85828E),
    accent = hex(0xC0687A),
    pink = hex(0xF7EBEE), peach = hex(0xF6EEE7), mint = hex(0xEAF2ED), lavender = hex(0xEEEDF5),
    butter = hex(0xF6F2E4), sky = hex(0xEAF0F6),
    series = listOf(hex(0xC0687A), hex(0x6B8CB8), hex(0x7FA588), hex(0xC4A064), hex(0x9585BF), hex(0x5E9EA0)),
    positive = hex(0x3B8A66), negative = hex(0xBF4E63),
    crypto = hex(0xD08A4E), savingsBar = hex(0xD9A0AE), realEstate = hex(0xA67B5B), otherBar = hex(0x9A97A3),
)

val DarkPalette = Palette(
    background = hex(0x141316), card = hex(0x1F1E22), ink = hex(0xF2F1F4), softInk = hex(0x9D9AA6),
    accent = hex(0xE0909E),
    pink = hex(0x2E2428), peach = hex(0x2E2924), mint = hex(0x222B26), lavender = hex(0x26252E),
    butter = hex(0x2C2A21), sky = hex(0x222830),
    series = listOf(hex(0xE0909E), hex(0x8FAEDA), hex(0x9CC5A6), hex(0xDDBB82), hex(0xB3A5DC), hex(0x82C0C2)),
    positive = hex(0x7CC5A1), negative = hex(0xF08A9C),
    crypto = hex(0xE8A673), savingsBar = hex(0xE8B7C3), realEstate = hex(0xC79B7B), otherBar = hex(0xB5B2BE),
)

val LocalPalette = staticCompositionLocalOf { LightPalette }

/** Shortcut to the current palette. */
val palette: Palette
    @Composable get() = LocalPalette.current

@Composable
fun BudgetTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val p = if (dark) DarkPalette else LightPalette
    val scheme = if (dark) {
        darkColorScheme(
            primary = p.accent, onPrimary = Color.White, background = p.background, onBackground = p.ink,
            surface = p.card, onSurface = p.ink, surfaceContainer = p.card, onSurfaceVariant = p.softInk,
            secondaryContainer = p.pink, onSecondaryContainer = p.ink, error = p.negative,
        )
    } else {
        lightColorScheme(
            primary = p.accent, onPrimary = Color.White, background = p.background, onBackground = p.ink,
            surface = p.card, onSurface = p.ink, surfaceContainer = p.card, onSurfaceVariant = p.softInk,
            secondaryContainer = p.pink, onSecondaryContainer = p.ink, error = p.negative,
        )
    }
    androidx.compose.runtime.CompositionLocalProvider(LocalPalette provides p) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

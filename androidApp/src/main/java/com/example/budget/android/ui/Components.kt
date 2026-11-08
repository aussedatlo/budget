package com.example.budget.android.ui

import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.budget.android.ui.theme.palette
import kotlin.math.abs
import kotlin.math.max

/** A soft rounded card. */
@Composable
fun BudgetCard(
    modifier: Modifier = Modifier,
    padding: Dp = 16.dp,
    color: Color = palette.card,
    content: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(18.dp)
    Box(
        modifier
            .fillMaxWidth()
            .shadow(2.dp, shape, ambientColor = Color.Black.copy(alpha = 0.04f), spotColor = Color.Black.copy(alpha = 0.06f))
            .clip(shape)
            .background(color)
            .padding(padding),
    ) { content() }
}

/** A card that can be tapped, and long-pressed for more. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TappableCard(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onLongClick: (() -> Unit)? = null,
    padding: Dp = 12.dp,
    content: @Composable () -> Unit,
) {
    BudgetCard(
        modifier.clip(RoundedCornerShape(18.dp)).combinedClickable(onClick = onClick, onLongClick = onLongClick),
        padding = padding,
        content = content,
    )
}

/** An emoji sitting in a pastel circle. */
@Composable
fun EmojiBubble(emoji: String, color: Color = palette.pink, size: Dp = 44.dp) {
    Box(Modifier.size(size).clip(CircleShape).background(color), contentAlignment = Alignment.Center) {
        Text(emoji, fontSize = (size.value * 0.5f).sp)
    }
}

/** Section title with an optional trailing value. */
@Composable
fun SectionTitle(title: String, trailing: String? = null) {
    Row(
        Modifier.fillMaxWidth().padding(start = 6.dp, end = 6.dp, top = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, color = palette.ink)
        Spacer(Modifier.weight(1f))
        if (trailing != null) {
            Text(trailing, style = MaterialTheme.typography.bodyMedium, color = palette.softInk)
        }
    }
}

/** Capsule button in the accent color. */
@Composable
fun PillButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = modifier,
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(containerColor = palette.accent, contentColor = Color.White),
    ) { Text(text, fontWeight = FontWeight.Bold) }
}

/** An empty state: what's missing and how to add it. */
@Composable
fun HintCard(title: String, text: String, vararg buttons: Pair<String, () -> Unit>) {
    BudgetCard {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = palette.ink)
            Spacer(Modifier.height(8.dp))
            Text(text, style = MaterialTheme.typography.bodyMedium, color = palette.softInk, textAlign = TextAlign.Center)
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                buttons.forEach { (label, action) -> PillButton(label, onClick = action) }
            }
        }
    }
}

/** A row on a card: icon, title and subtitle, then an amount. */
@Composable
fun ItemRow(
    emoji: String,
    tint: Color,
    title: String,
    subtitle: String?,
    trailing: String,
    trailingColor: Color = palette.ink,
    subtitleTag: String? = null,
    struck: Boolean = false,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        EmojiBubble(emoji, tint)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = palette.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (subtitle != null) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = palette.softInk,
                    modifier = if (subtitleTag != null) Modifier.testTag(subtitleTag) else Modifier,
                )
            }
        }
        Spacer(Modifier.width(8.dp))
        Text(
            trailing,
            style = MaterialTheme.typography.titleMedium.copy(
                textDecoration = if (struck) androidx.compose.ui.text.style.TextDecoration.LineThrough else null,
            ),
            color = trailingColor,
        )
    }
}

/** One part of a [CompositionBar]. */
data class BarPart(
    val label: String,
    /** Its width in the bar (nothing below 0 is drawn). */
    val amount: Double,
    val color: Color,
    /** The amount written in the legend when it differs from the bar, e.g. how much over budget. */
    val shown: Double? = null,
    /** Written in red in the legend. */
    val isWarning: Boolean = false,
) {
    val legendAmount: Double get() = shown ?: amount
}

/**
 * A bar split into colored parts, with a legend giving each part's amount and
 * share. When the parts go past `total`, the bar fills up and a tick marks
 * where the total ends.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CompositionBar(parts: List<BarPart>, total: Double? = null) {
    val drawn = parts.filter { it.amount > 0 }
    val listed = parts.filter { it.amount > 0 || it.shown != null }
    val sum = drawn.sumOf { it.amount }
    val base = total ?: sum
    val scale = maxOf(base, sum, 1.0)
    val p = palette
    val money = LocalMoney.current
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Canvas(Modifier.fillMaxWidth().height(14.dp).testTag("header-bar").semantics { contentDescription = "Composition" }) {
            val gap = 2.dp.toPx()
            val usable = size.width - gap * max(drawn.size - 1, 0)
            val capsule = Path().apply {
                addRoundRect(RoundRect(0f, 0f, size.width, size.height, CornerRadius(size.height / 2)))
            }
            drawPath(capsule, p.background)
            clipPath(capsule) {
                var x = 0f
                drawn.forEach { part ->
                    val w = (usable * part.amount / scale).toFloat()
                    drawRect(part.color, Offset(x, 0f), Size(w, size.height))
                    x += w + gap
                }
            }
            // Where the total ends when the parts go past it
            if (sum > base + 0.005 && base > 0) {
                val tick = (size.width * base / scale).toFloat()
                drawRect(p.ink, Offset(tick - 1.dp.toPx(), -4.dp.toPx()), Size(2.dp.toPx(), size.height + 8.dp.toPx()))
            }
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            listed.forEach { part ->
                val amount = abs(part.legendAmount)
                val text = if (base > 0) "${money.format(amount)} · ${(amount / base).percent()}" else money.format(amount)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.testTag("legend-${part.label}").semantics(mergeDescendants = true) {},
                ) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(if (part.isWarning) p.negative else part.color))
                    Spacer(Modifier.width(6.dp))
                    Column {
                        Text(part.label, style = MaterialTheme.typography.labelSmall, color = p.softInk)
                        Text(
                            text, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold,
                            color = if (part.isWarning) p.negative else p.ink,
                        )
                    }
                }
            }
        }
    }
}

/**
 * The header at the top of Budget, Income and Wealth: the tab's mascot, a
 * title, one large amount and a bar showing what that amount is made of.
 */
@Composable
fun TabHeader(
    title: String,
    value: Double,
    valueColor: Color = palette.ink,
    bar: (@Composable () -> Unit)?,
    icon: @Composable () -> Unit,
    accessory: @Composable () -> Unit = {},
    caption: @Composable () -> Unit = {},
) {
    BudgetCard {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.width(88.dp), contentAlignment = Alignment.Center) { icon() }
                Spacer(Modifier.width(16.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(title, style = MaterialTheme.typography.bodyMedium, color = palette.softInk,
                            modifier = Modifier.weight(1f).testTag("header-title"))
                        accessory()
                    }
                    Text(
                        value.currency,
                        fontSize = 30.sp,
                        fontWeight = FontWeight.Bold,
                        color = valueColor,
                        maxLines = 1,
                        modifier = Modifier.testTag("header-value"),
                    )
                    caption()
                }
            }
            bar?.invoke()
        }
    }
}

/** An emoji that floats gently, the mascot of a tab. */
@Composable
fun Mascot(emoji: String, bounce: Boolean = true) {
    val transition = androidx.compose.animation.core.rememberInfiniteTransition(label = "mascot")
    val offset by transition.animateFloat(
        initialValue = 0f,
        targetValue = if (bounce) -6f else 0f,
        animationSpec = androidx.compose.animation.core.infiniteRepeatable(
            androidx.compose.animation.core.tween(1400),
            androidx.compose.animation.core.RepeatMode.Reverse,
        ),
        label = "float",
    )
    Text(emoji, fontSize = 56.sp, modifier = Modifier.padding(top = (6 + offset).coerceAtLeast(0f).dp))
}

/** A number field that accepts a dot or a comma. Empty is null. */
@Composable
fun AmountField(
    label: String,
    value: Double?,
    onChange: (Double?) -> Unit,
    tag: String,
    modifier: Modifier = Modifier,
) {
    var text by remember { mutableStateOf(value?.plain() ?: "") }
    // Follows a value set from outside (e.g. computed), unless it's what's typed
    if (parseAmount(text) != value && !(text.isBlank() && value == null)) {
        text = value?.plain() ?: ""
    }
    OutlinedTextField(
        value = text,
        onValueChange = {
            text = it
            onChange(parseAmount(it))
        },
        label = { Text(label) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        modifier = modifier.fillMaxWidth().testTag(tag),
    )
}

/** A plain text field. */
@Composable
fun TextInput(label: String, value: String, onChange: (String) -> Unit, tag: String, modifier: Modifier = Modifier) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        singleLine = true,
        modifier = modifier.fillMaxWidth().testTag(tag),
    )
}

/** Asks before deleting. */
@Composable
fun ConfirmDelete(title: String, message: String = "This can't be undone.", onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(message) },
        confirmButton = {
            TextButton(onClick = { onConfirm(); onDismiss() }) { Text("Delete", color = palette.negative) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

/** A small label / value block used in summary cards. */
@Composable
fun StatTile(title: String, value: String, modifier: Modifier = Modifier, color: Color = palette.ink) {
    Column(modifier) {
        Text(title, style = MaterialTheme.typography.bodySmall, color = palette.softInk)
        Text(value, style = MaterialTheme.typography.titleMedium, color = color, maxLines = 1)
    }
}

/** A rounded chip for small values like a gain percentage. */
@Composable
fun Chip(text: String, color: Color = palette.ink, background: Color = palette.background) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Bold,
        color = color,
        modifier = Modifier.clip(CircleShape).background(background).padding(horizontal = 10.dp, vertical = 5.dp),
    )
}

/** A horizontal progress bar. */
@Composable
fun ProgressBar(ratio: Double, color: Color, modifier: Modifier = Modifier) {
    val animated by animateFloatAsState(ratio.coerceIn(0.0, 1.0).toFloat(), label = "progress")
    val p = palette
    Canvas(modifier.fillMaxWidth().height(8.dp)) {
        drawRoundRect(p.background, cornerRadius = CornerRadius(size.height / 2))
        drawRoundRect(color, size = Size(size.width * animated, size.height), cornerRadius = CornerRadius(size.height / 2))
    }
}

/** Emoji to pick for an item, plus one typed by hand. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EmojiPicker(selected: String, suggestions: List<String>, onPick: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            suggestions.forEach { emoji ->
                val isSelected = emoji == selected
                Box(
                    Modifier.size(44.dp).clip(CircleShape)
                        .background(if (isSelected) palette.accent.copy(alpha = 0.25f) else palette.background)
                        .combinedClickableCompat { onPick(emoji) },
                    contentAlignment = Alignment.Center,
                ) { Text(emoji, fontSize = 22.sp) }
            }
        }
        TextInput("Or type an emoji", if (selected in suggestions) "" else selected, { typed ->
            onPick(typed.trim().take(8))
        }, tag = "emoji-input")
    }
}

@OptIn(ExperimentalFoundationApi::class)
private fun Modifier.combinedClickableCompat(onClick: () -> Unit) = combinedClickable(onClick = onClick)

object Emoji {
    val charges = listOf("🏠", "💡", "⚡️", "💧", "🔥", "📶", "📱", "🛡️", "📺", "🎵", "🚗", "🚌", "⛽️", "💊", "🧘‍♀️", "🏦", "🎮", "🐾", "👶", "🛒", "🌸")
    val income = listOf("💼", "🏢", "💻", "🎓", "🏠", "🎁", "📈", "🧾", "🛍️", "🎨", "💰", "🌸")
    val investments = listOf("🌍", "📈", "💼", "🪙", "🥇", "🐷", "🏠", "💎", "🏦", "🌱", "🚀", "💶")
    val people = listOf("💸", "🚗", "🎓", "🏠", "👪", "🧑‍🤝‍🧑", "💍", "🎁", "🛠️", "✈️", "🌸")
    val homes = listOf("🏠", "🏡", "🏢", "🏘️", "🏰", "⛺️")
}

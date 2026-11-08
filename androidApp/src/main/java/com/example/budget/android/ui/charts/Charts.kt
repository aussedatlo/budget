package com.example.budget.android.ui.charts

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.background
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.budget.android.ui.compact
import com.example.budget.android.ui.shortMonth
import com.example.budget.android.ui.theme.palette
import kotlin.time.Instant

/** A line of a [LineChart]: (date, value) points in order. */
data class Series(
    val name: String,
    val color: Color,
    val points: List<Pair<Instant, Double>>,
    val dashed: Boolean = false,
    /** Fills the area under the line. */
    val filled: Boolean = false,
)

/** Lines over time, with a value axis on the right and the first and last dates below. */
@Composable
fun LineChart(
    series: List<Series>,
    modifier: Modifier = Modifier,
    height: Dp = 180.dp,
    selected: Instant? = null,
    onSelect: ((Instant) -> Unit)? = null,
) {
    val all = series.flatMap { it.points }
    if (all.isEmpty()) return
    val measurer = rememberTextMeasurer()
    val p = palette
    val minX = all.minOf { it.first.toEpochMilliseconds() }.toFloat()
    val maxX = all.maxOf { it.first.toEpochMilliseconds() }.toFloat()
    val (minY, maxY) = niceRange(all.minOf { it.second }, all.maxOf { it.second })
    val dates = all.map { it.first }.distinct().sorted()

    Column(modifier) {
        Canvas(
            Modifier.fillMaxWidth().height(height).testTag("chart").pointerInput(dates, onSelect) {
                if (onSelect != null) {
                    detectTapGestures { offset ->
                        val plot = size.width - 44.dp.toPx()
                        val x = minX + (offset.x / plot).coerceIn(0f, 1f) * (maxX - minX)
                        dates.minByOrNull { kotlin.math.abs(it.toEpochMilliseconds() - x) }?.let(onSelect)
                    }
                }
            },
        ) {
            val axis = 44.dp.toPx()
            val plotW = size.width - axis
            val plotH = size.height - 18.dp.toPx()
            fun px(t: Instant) = if (maxX == minX) plotW / 2 else (t.toEpochMilliseconds() - minX) / (maxX - minX) * plotW
            fun py(v: Double) = (plotH - ((v - minY) / (maxY - minY)) * plotH).toFloat()

            // Grid and value axis
            for (i in 0..3) {
                val v = minY + (maxY - minY) * i / 3
                val y = py(v)
                drawLine(p.softInk.copy(alpha = 0.15f), Offset(0f, y), Offset(plotW, y), 1f)
                label(measurer, v.compact(), Offset(plotW + 6.dp.toPx(), y - 7.dp.toPx()), p.softInk)
            }
            label(measurer, dates.first().shortMonth(), Offset(0f, plotH + 2.dp.toPx()), p.softInk)
            if (dates.size > 1) {
                val last = dates.last().shortMonth()
                label(measurer, last, Offset(plotW - 40.dp.toPx(), plotH + 2.dp.toPx()), p.softInk)
            }

            series.forEach { s ->
                if (s.points.isEmpty()) return@forEach
                val path = Path()
                s.points.forEachIndexed { i, (t, v) ->
                    if (i == 0) path.moveTo(px(t), py(v)) else path.lineTo(px(t), py(v))
                }
                if (s.filled && s.points.size > 1) {
                    val area = Path().apply {
                        addPath(path)
                        lineTo(px(s.points.last().first), plotH)
                        lineTo(px(s.points.first().first), plotH)
                        close()
                    }
                    drawPath(area, s.color.copy(alpha = 0.12f))
                }
                drawPath(
                    path, s.color,
                    style = Stroke(
                        width = 2.5.dp.toPx(),
                        pathEffect = if (s.dashed) PathEffect.dashPathEffect(floatArrayOf(10f, 8f)) else null,
                    ),
                )
                if (s.points.size == 1) drawCircle(s.color, 4.dp.toPx(), Offset(px(s.points[0].first), py(s.points[0].second)))
            }

            if (selected != null) {
                val x = px(selected)
                drawLine(p.ink.copy(alpha = 0.4f), Offset(x, 0f), Offset(x, plotH), 1.5f)
                series.forEach { s ->
                    s.points.firstOrNull { it.first == selected }?.let { drawCircle(s.color, 5.dp.toPx(), Offset(x, py(it.second))) }
                }
            }
        }
        if (series.size > 1) Legend(series.map { it.name to it.color })
    }
}

/** One bar per group, each split into colored parts. */
data class BarGroup(val date: Instant, val parts: List<Pair<String, Double>>)

@Composable
fun StackedBarChart(
    groups: List<BarGroup>,
    colors: Map<String, Color>,
    modifier: Modifier = Modifier,
    height: Dp = 180.dp,
    selected: Instant? = null,
    onSelect: ((Instant) -> Unit)? = null,
) {
    if (groups.isEmpty()) return
    val measurer = rememberTextMeasurer()
    val p = palette
    val tops = groups.map { g -> g.parts.sumOf { maxOf(it.second, 0.0) } }
    val bottoms = groups.map { g -> g.parts.sumOf { minOf(it.second, 0.0) } }
    val (minY, maxY) = niceRange(minOf(bottoms.min(), 0.0), maxOf(tops.max(), 0.0))
    Column(modifier) {
        Canvas(
            Modifier.fillMaxWidth().height(height).testTag("chart").pointerInput(groups, onSelect) {
                if (onSelect != null) {
                    detectTapGestures { offset ->
                        val plot = size.width - 44.dp.toPx()
                        val i = ((offset.x / plot) * groups.size).toInt().coerceIn(0, groups.lastIndex)
                        onSelect(groups[i].date)
                    }
                }
            },
        ) {
            val axis = 44.dp.toPx()
            val plotW = size.width - axis
            val plotH = size.height - 18.dp.toPx()
            fun py(v: Double) = (plotH - ((v - minY) / (maxY - minY)) * plotH).toFloat()
            for (i in 0..3) {
                val v = minY + (maxY - minY) * i / 3
                drawLine(p.softInk.copy(alpha = 0.15f), Offset(0f, py(v)), Offset(plotW, py(v)), 1f)
                label(measurer, v.compact(), Offset(plotW + 6.dp.toPx(), py(v) - 7.dp.toPx()), p.softInk)
            }
            val slot = plotW / groups.size
            val barW = slot * 0.6f
            groups.forEachIndexed { i, g ->
                val x = i * slot + (slot - barW) / 2
                var up = 0.0
                var down = 0.0
                val alpha = if (selected == null || selected == g.date) 1f else 0.4f
                g.parts.forEach { (name, v) ->
                    val color = (colors[name] ?: p.accent).copy(alpha = alpha)
                    if (v >= 0) {
                        drawRoundRect(color, Offset(x, py(up + v)), Size(barW, py(up) - py(up + v)), CornerRadius(3f))
                        up += v
                    } else {
                        drawRoundRect(color, Offset(x, py(down)), Size(barW, py(down + v) - py(down)), CornerRadius(3f))
                        down += v
                    }
                }
            }
            label(measurer, groups.first().date.shortMonth(), Offset(0f, plotH + 2.dp.toPx()), p.softInk)
            if (groups.size > 1) label(measurer, groups.last().date.shortMonth(), Offset(plotW - 40.dp.toPx(), plotH + 2.dp.toPx()), p.softInk)
        }
        Legend(colors.entries.filter { e -> groups.any { g -> g.parts.any { it.first == e.key } } }.map { it.key to it.value })
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun Legend(items: List<Pair<String, Color>>) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        items.forEach { (name, color) ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(8.dp).clip(CircleShape).background(color))
                Spacer(Modifier.width(4.dp))
                Text(name, style = MaterialTheme.typography.labelSmall, color = palette.softInk)
            }
        }
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.label(measurer: TextMeasurer, text: String, at: Offset, color: Color) {
    drawText(measurer, text, at, TextStyle(fontSize = 10.sp, color = color))
}

/** A range with a little room above and below, never empty. */
private fun niceRange(min: Double, max: Double): Pair<Double, Double> {
    if (max - min < 1e-6) return (min - 1).coerceAtMost(min) to max + 1
    val pad = (max - min) * 0.08
    val low = if (min >= 0 && min - pad < 0) 0.0 else min - pad
    return low to max + pad
}

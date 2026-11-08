package com.example.budget.core

import kotlin.time.Clock
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Instant
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.minus
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime

/**
 * The calendar every calculation uses: days and months are counted in
 * [timeZone], and "now" comes from [clock]. Tests set both.
 */
object BudgetCalendar {
    var timeZone: TimeZone = TimeZone.currentSystemDefault()
    var clock: Clock = Clock.System

    fun now(): Instant = clock.now()

    /** Later than any recorded date. */
    val distantFuture: Instant = Instant.DISTANT_FUTURE
    val distantPast: Instant = Instant.DISTANT_PAST

    fun date(instant: Instant): LocalDate = instant.toLocalDateTime(timeZone).date

    fun startOfDay(instant: Instant): Instant = date(instant).atStartOfDayIn(timeZone)

    /** The last second of the day `instant` is in. */
    fun endOfDay(instant: Instant): Instant =
        date(instant).plus(1, DateTimeUnit.DAY).atStartOfDayIn(timeZone) - 1.seconds

    /** First moment of the month `instant` is in. */
    fun startOfMonth(instant: Instant): Instant = firstDayOfMonth(instant).atStartOfDayIn(timeZone)

    /** The last second of the month `instant` is in. */
    fun endOfMonth(instant: Instant): Instant =
        firstDayOfMonth(instant).plus(1, DateTimeUnit.MONTH).atStartOfDayIn(timeZone) - 1.seconds

    /** Start of the month `months` after (or before, when negative) the one `instant` is in. */
    fun addMonths(instant: Instant, months: Int): Instant =
        firstDayOfMonth(instant).plus(months, DateTimeUnit.MONTH).atStartOfDayIn(timeZone)

    /** Same time of day, `days` later (or earlier). */
    fun addDays(instant: Instant, days: Int): Instant {
        val local = instant.toLocalDateTime(timeZone)
        val day = local.date.plus(days, DateTimeUnit.DAY)
        return instant + (day.atStartOfDayIn(timeZone) - local.date.atStartOfDayIn(timeZone))
    }

    fun isSameDay(a: Instant, b: Instant): Boolean = date(a) == date(b)

    fun isSameMonth(a: Instant, b: Instant): Boolean {
        val x = date(a)
        val y = date(b)
        return x.year == y.year && x.month == y.month
    }

    /** Number of calendar months from `start` to `end` (0 within the same month, never negative). */
    fun monthsBetween(start: Instant, end: Instant): Int {
        val from = date(start)
        val to = date(end)
        val months = (to.year - from.year) * 12 + (to.month.ordinal - from.month.ordinal)
        return maxOf(months, 0)
    }

    /** Start of the given day. */
    fun day(year: Int, month: Int, day: Int): Instant =
        LocalDate(year, month, day).atStartOfDayIn(timeZone)

    fun fromEpochMillis(millis: Long): Instant = Instant.fromEpochMilliseconds(millis)

    fun fromEpochSeconds(seconds: Double): Instant =
        Instant.fromEpochMilliseconds(kotlin.math.round(seconds * 1000).toLong())

    fun epochSeconds(instant: Instant): Double = instant.toEpochMilliseconds() / 1000.0

    private fun firstDayOfMonth(instant: Instant): LocalDate {
        val day = date(instant)
        return day.minus(day.day - 1, DateTimeUnit.DAY)
    }
}

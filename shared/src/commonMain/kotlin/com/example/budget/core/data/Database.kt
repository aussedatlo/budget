package com.example.budget.core.data

import com.example.budget.core.db.BudgetDatabase
import kotlin.time.Instant

// How values are stored: dates as epoch milliseconds, booleans as 0 or 1.

internal val Instant.millis: Long get() = toEpochMilliseconds()
internal val Long.instant: Instant get() = Instant.fromEpochMilliseconds(this)
internal fun Boolean.toLong(): Long = if (this) 1L else 0L

/** The id of the row the latest insert added. */
internal fun BudgetDatabase.lastId(): Long = metaQueries.lastId().executeAsOne()

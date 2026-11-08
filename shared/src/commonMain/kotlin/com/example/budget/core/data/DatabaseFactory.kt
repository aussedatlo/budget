package com.example.budget.core.data

import app.cash.sqldelight.db.SqlDriver

/** Name of the database file. */
const val DATABASE_NAME = "budget.db"

/** Opens the database on each platform: the real file, or a fresh one in memory for the demo data and tests. */
expect class DatabaseFactory {
    fun create(inMemory: Boolean): SqlDriver
}

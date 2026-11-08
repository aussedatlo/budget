package com.example.budget.core.data

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import com.example.budget.core.db.BudgetDatabase

/** For tests and tools on a computer: `path` is the database file. */
actual class DatabaseFactory(private val path: String = DATABASE_NAME) {
    actual fun create(inMemory: Boolean): SqlDriver {
        val url = if (inMemory) JdbcSqliteDriver.IN_MEMORY else "jdbc:sqlite:$path"
        return JdbcSqliteDriver(url, schema = BudgetDatabase.Schema)
    }
}

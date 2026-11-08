package com.example.budget.core.data

import android.content.Context
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import com.example.budget.core.db.BudgetDatabase

actual class DatabaseFactory(private val context: Context) {
    actual fun create(inMemory: Boolean): SqlDriver =
        AndroidSqliteDriver(BudgetDatabase.Schema, context, if (inMemory) null else DATABASE_NAME)
}

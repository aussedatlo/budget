package com.example.budget.core.data

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import app.cash.sqldelight.driver.native.wrapConnection
import co.touchlab.sqliter.DatabaseConfiguration
import com.example.budget.core.db.BudgetDatabase
import kotlin.random.Random

actual class DatabaseFactory {
    actual fun create(inMemory: Boolean): SqlDriver {
        val schema = BudgetDatabase.Schema
        // Each in-memory database gets a name of its own, so starting over
        // on the demo data shares nothing with the one before
        val name = if (inMemory) "demo-${Random.nextLong()}.db" else DATABASE_NAME
        return NativeSqliteDriver(
            DatabaseConfiguration(
                name = name,
                inMemory = inMemory,
                version = schema.version.toInt(),
                create = { connection -> wrapConnection(connection) { schema.create(it) } },
                upgrade = { connection, old, new ->
                    wrapConnection(connection) { schema.migrate(it, old.toLong(), new.toLong()) }
                },
            ),
        )
    }
}

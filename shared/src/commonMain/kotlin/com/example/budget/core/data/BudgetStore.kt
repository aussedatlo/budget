package com.example.budget.core.data

import com.example.budget.core.BudgetCalendar
import com.example.budget.core.DemoData

/** Opens the app's data: the real database, or the demo data in memory. */
object BudgetStore {
    fun open(factory: DatabaseFactory): BudgetRepository = BudgetRepository(factory.create(inMemory = false))

    /** A fresh database in memory with the sample data of the UI tests. */
    fun openDemo(factory: DatabaseFactory, missedMonths: Int = 0): BudgetRepository {
        val repository = BudgetRepository(factory.create(inMemory = true))
        repository.insertAll(DemoData.state(missedMonths, BudgetCalendar.now()))
        LegacyImport.skip(repository)
        return repository
    }
}

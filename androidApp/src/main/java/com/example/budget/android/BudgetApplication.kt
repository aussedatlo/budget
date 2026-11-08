package com.example.budget.android

import android.app.Application
import com.example.budget.core.data.BudgetRepository
import com.example.budget.core.data.BudgetStore
import com.example.budget.core.data.DatabaseFactory
import com.example.budget.core.data.LegacyImport

class BudgetApplication : Application() {
    /** The user's data, opened on first use. The demo data never goes through it. */
    val repository: BudgetRepository by lazy {
        BudgetStore.open(DatabaseFactory(this)).also { LegacyImport.skip(it) }
    }
}

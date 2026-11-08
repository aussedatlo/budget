package com.example.budget.android

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.example.budget.core.BudgetState
import com.example.budget.core.data.BudgetRepository
import com.example.budget.core.data.BudgetStore
import com.example.budget.core.data.DatabaseFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * What the screens read and change. Changes go to the shared repository on
 * one background thread, in order; the new state comes back through [state].
 */
class BudgetViewModel(
    val repository: BudgetRepository,
    private val settings: Settings,
) : ViewModel() {
    @OptIn(ExperimentalCoroutinesApi::class)
    private val writes = Dispatchers.IO.limitedParallelism(1)

    val state: StateFlow<BudgetState> = repository.state

    private val _currency = MutableStateFlow(settings.currency)
    /** The display currency (ISO code). */
    val currency: StateFlow<String> = _currency.asStateFlow()

    fun setCurrency(code: String) {
        settings.currency = code
        _currency.value = code
    }

    /** Runs a change on the database thread. */
    fun update(change: BudgetRepository.() -> Unit) {
        viewModelScope.launch(writes) { repository.change() }
    }

    companion object {
        fun factory(context: BudgetApplication, demo: Boolean, missedMonths: Int): ViewModelProvider.Factory =
            viewModelFactory {
                initializer {
                    if (demo) {
                        BudgetViewModel(
                            BudgetStore.openDemo(DatabaseFactory(context), missedMonths),
                            Settings.inMemory("EUR"),
                        )
                    } else {
                        BudgetViewModel(context.repository, Settings.of(context))
                    }
                }
            }
    }
}

/** The app's few settings. */
interface Settings {
    var currency: String

    companion object {
        fun defaultCurrency(): String =
            runCatching { java.util.Currency.getInstance(java.util.Locale.getDefault()).currencyCode }.getOrNull() ?: "EUR"

        fun of(context: Context): Settings = object : Settings {
            private val prefs = context.getSharedPreferences("settings", Context.MODE_PRIVATE)
            override var currency: String
                get() = prefs.getString("currencyCode", null) ?: defaultCurrency()
                set(value) = prefs.edit().putString("currencyCode", value).apply()
        }

        fun inMemory(currency: String): Settings = object : Settings {
            override var currency: String = currency
        }
    }
}

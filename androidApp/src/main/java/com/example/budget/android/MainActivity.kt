package com.example.budget.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.example.budget.android.ui.BudgetApp
import com.example.budget.android.ui.theme.BudgetTheme

/**
 * The only activity. Started with the extra `demo-data` (true), it shows the
 * sample data in memory instead of the user's data, for tests and screenshots;
 * `demo-tab` picks the first tab and `demo-missed-months` leaves months out.
 */
class MainActivity : ComponentActivity() {
    private val model: BudgetViewModel by viewModels {
        BudgetViewModel.factory(
            application as BudgetApplication,
            demo = intent.getBooleanExtra(EXTRA_DEMO, false),
            missedMonths = intent.getIntExtra(EXTRA_MISSED_MONTHS, 0),
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val startTab = intent.getStringExtra(EXTRA_TAB)
        setContent {
            BudgetTheme {
                BudgetApp(model, startTab = startTab)
            }
        }
    }

    companion object {
        const val EXTRA_DEMO = "demo-data"
        const val EXTRA_TAB = "demo-tab"
        const val EXTRA_MISSED_MONTHS = "demo-missed-months"
    }
}

package com.example.budget.android.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.budget.android.BudgetViewModel
import com.example.budget.android.ui.budget.BudgetScreen
import com.example.budget.android.ui.budget.ChargeForm
import com.example.budget.android.ui.budget.SavingsPlanSheet
import com.example.budget.android.ui.income.IncomeScreen
import com.example.budget.android.ui.income.IncomeSourceForm
import com.example.budget.android.ui.income.LendingDetailScreen
import com.example.budget.android.ui.income.LendingForm
import com.example.budget.android.ui.income.LendingValueForm
import com.example.budget.android.ui.settings.SettingsSheet
import com.example.budget.android.ui.snapshot.SnapshotSheet
import com.example.budget.android.ui.theme.palette
import com.example.budget.android.ui.trends.SnapshotDetailSheet
import com.example.budget.android.ui.trends.TrendsScreen
import com.example.budget.android.ui.wealth.InvestmentDetailScreen
import com.example.budget.android.ui.wealth.InvestmentForm
import com.example.budget.android.ui.wealth.LoanDetailScreen
import com.example.budget.android.ui.wealth.LoanForm
import com.example.budget.android.ui.wealth.LoanValueForm
import com.example.budget.android.ui.wealth.ValueForm
import com.example.budget.android.ui.wealth.WealthScreen
import com.example.budget.core.BudgetState
import com.example.budget.core.data.BudgetRepository
import com.example.budget.core.snapshots.Trends
import com.example.budget.core.wealth.Wealth

enum class Tab(val label: String, val emoji: String) {
    Budget("Budget", "👛"),
    Income("Income", "💵"),
    Wealth("Wealth", "📈"),
    Trends("Trends", "📊");

    companion object {
        /** Also takes the names the iOS app uses (`monthly`, `investments`, `stats`). */
        fun from(name: String?): Tab = when (name?.lowercase()) {
            "income" -> Income
            "wealth", "investments" -> Wealth
            "trends", "stats" -> Trends
            else -> Budget
        }
    }
}

/** A screen pushed over a tab. */
sealed interface Route {
    data class Lending(val id: Long) : Route
    data class Investment(val id: Long) : Route
    data class Loan(val id: Long) : Route
}

/** A form or a screen shown over everything, like a sheet on iOS. */
sealed interface Sheet {
    data object Settings : Sheet
    data object Snapshot : Sheet
    data object SavingsPlan : Sheet
    data class Charge(val id: Long?) : Sheet
    data class IncomeSource(val id: Long?) : Sheet
    data class Lending(val id: Long?) : Sheet
    data class LendingValue(val lendingId: Long, val snapshotId: Long?) : Sheet
    data class Investment(val id: Long?) : Sheet
    data class Value(val investmentId: Long, val snapshotId: Long?) : Sheet
    data class Loan(val id: Long?) : Sheet
    data class LoanValue(val loanId: Long, val snapshotId: Long?) : Sheet
    data class SnapshotDetail(val id: Long) : Sheet
}

/** Moves between screens, and changes the data. */
class Nav(
    private val stack: MutableList<Route>,
    private val setSheet: (Sheet?) -> Unit,
    private val setTab: (Tab) -> Unit,
    private val model: BudgetViewModel,
) {
    fun open(route: Route) { stack += route }
    fun back() { if (stack.isNotEmpty()) stack.removeAt(stack.lastIndex) }
    fun present(sheet: Sheet) = setSheet(sheet)
    fun dismiss() = setSheet(null)
    fun select(tab: Tab) { stack.clear(); setTab(tab) }
    fun update(change: BudgetRepository.() -> Unit) = model.update(change)
}

@Composable
fun BudgetApp(model: BudgetViewModel, startTab: String? = null) {
    val state by model.state.collectAsStateWithLifecycle()
    val currency by model.currency.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(Tab.from(startTab)) }
    var sheet by remember { mutableStateOf<Sheet?>(null) }
    val stack = remember { mutableStateListOf<Route>() }
    val nav = remember(model) { Nav(stack, { sheet = it }, { tab = it }, model) }

    BackHandler(enabled = stack.isNotEmpty()) { nav.back() }

    CompositionLocalProvider(LocalMoney provides remember(currency) { Money(currency) }) {
        Scaffold(
            containerColor = palette.background,
            bottomBar = {
                NavigationBar(containerColor = palette.card) {
                    Tab.entries.forEach { item ->
                        NavigationBarItem(
                            selected = tab == item,
                            onClick = { nav.select(item) },
                            icon = { Text(item.emoji) },
                            label = { Text(item.label) },
                            modifier = Modifier.testTag("tab-${item.label}"),
                            colors = NavigationBarItemDefaults.colors(
                                selectedTextColor = palette.accent,
                                indicatorColor = palette.pink,
                            ),
                        )
                    }
                }
            },
        ) { padding ->
            Box(Modifier.padding(padding)) {
                when (val route = stack.lastOrNull()) {
                    is Route.Lending -> LendingDetailScreen(state, route.id, nav)
                    is Route.Investment -> InvestmentDetailScreen(state, route.id, nav)
                    is Route.Loan -> LoanDetailScreen(state, route.id, nav)
                    null -> when (tab) {
                        Tab.Budget -> BudgetScreen(state, nav)
                        Tab.Income -> IncomeScreen(state, nav)
                        Tab.Wealth -> WealthScreen(state, nav)
                        Tab.Trends -> TrendsScreen(state, nav)
                    }
                }
            }
        }

        sheet?.let { SheetContent(it, state, nav, currency, model::setCurrency) }
    }
}

@Composable
private fun SheetContent(sheet: Sheet, state: BudgetState, nav: Nav, currency: String, setCurrency: (String) -> Unit) {
    when (sheet) {
        Sheet.Settings -> SettingsSheet(currency, setCurrency, nav)
        Sheet.Snapshot -> SnapshotSheet(state, nav)
        Sheet.SavingsPlan -> SavingsPlanSheet(state, nav)
        is Sheet.Charge -> ChargeForm(state.charges.firstOrNull { it.id == sheet.id }, nav)
        is Sheet.IncomeSource -> IncomeSourceForm(state.incomeSources.firstOrNull { it.id == sheet.id }, nav)
        is Sheet.Lending -> LendingForm(state.lendings.firstOrNull { it.id == sheet.id }, nav)
        is Sheet.LendingValue -> state.lending(sheet.lendingId)?.let { LendingValueForm(it, sheet.snapshotId, nav) }
        is Sheet.Investment -> InvestmentForm(state.investments.firstOrNull { it.id == sheet.id }, nav)
        is Sheet.Value -> state.investment(sheet.investmentId)?.let { ValueForm(it, sheet.snapshotId, nav) }
        is Sheet.Loan -> LoanForm(state.loans.firstOrNull { it.id == sheet.id }, nav)
        is Sheet.LoanValue -> state.loan(sheet.loanId)?.let { LoanValueForm(it, sheet.snapshotId, nav) }
        is Sheet.SnapshotDetail -> state.snapshot(sheet.id)?.let { SnapshotDetailSheet(state, it, nav) }
    }
}

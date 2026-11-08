package com.example.budget.android

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.test.core.app.ApplicationProvider
import com.example.budget.android.ui.BudgetApp
import com.example.budget.android.ui.theme.BudgetTheme
import com.example.budget.core.charges.FixedCharge
import com.example.budget.core.data.BudgetStore
import com.example.budget.core.data.DatabaseFactory
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The Budget scenarios of the iOS UI tests, on the same demo data, run on
 * the JVM with Robolectric. Amounts are in euros with English formatting.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class BudgetAppTest {
    @get:Rule val rule = createComposeRule()
    private lateinit var model: BudgetViewModel

    @Before fun setUp() {
        Locale.setDefault(Locale.US)
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        model = BudgetViewModel(BudgetStore.openDemo(DatabaseFactory(context)), Settings.inMemory("EUR"))
        rule.setContent { BudgetTheme(dark = false) { BudgetApp(model) } }
    }

    private fun waitFor(text: String) = rule.waitUntil(5_000) {
        rule.onAllNodes(hasText(text, substring = true)).fetchSemanticsNodes().isNotEmpty()
    }

    private fun waitUntilGone(text: String) = rule.waitUntil(5_000) {
        rule.onAllNodes(hasText(text)).fetchSemanticsNodes().isEmpty()
    }

    @Test fun seeWhatIsLeftAfterSavings() {
        rule.onNodeWithTag("screen-title").assertTextContains("Budget")
        rule.onNodeWithTag("header-title").assertTextContains("Left after savings")
        rule.onNodeWithTag("header-value").assertTextContains("€1,609.02")
        rule.onNodeWithText("of €3,150.00 income", substring = true).assertExists()
    }

    @Test fun overBudget() {
        model.update { saveCharge(FixedCharge(title = "Car loan", amount = 5_000.0)) }
        waitFor("Over budget")
        rule.onNodeWithTag("header-title").assertTextContains("Over budget")
    }

    @Test fun openTheIncomeTabFromTheIncomeLine() {
        rule.onNodeWithTag("open-income").performClick()
        rule.onNodeWithTag("screen-title").assertTextContains("Income")
        rule.onNodeWithTag("header-title").assertTextContains("Monthly income")
    }

    @Test fun chargesAreSortedByAmount() {
        val titles = model.state.value.charges.map { it.title }
        assertEquals(listOf("Rent", "Electricity", "Car insurance", "Yoga", "Internet", "Netflix"), titles)
    }

    @Test fun addACharge() {
        rule.onNodeWithTag("add-button").performClick()
        rule.onNodeWithTag("sheet-title").assertTextContains("New charge")
        rule.onNodeWithTag("save").assertIsNotEnabled()
        rule.onNodeWithTag("charge-title").performTextInput("Phone")
        rule.onNodeWithTag("save").assertIsNotEnabled()
        rule.onNodeWithTag("charge-amount").performTextInput("15")
        rule.onNodeWithTag("save").assertIsEnabled().performClick()
        waitFor("Phone")
        rule.onNodeWithTag("charge-Phone").performScrollTo().assertExists()
    }

    @Test fun editACharge() {
        rule.onNodeWithTag("charge-Rent").performScrollTo().performClick()
        rule.onNodeWithTag("sheet-title").assertTextContains("Edit charge")
        rule.onNodeWithTag("charge-amount").performTextReplacement("900")
        rule.onNodeWithTag("save").performClick()
        waitFor("€900.00")
        rule.onNodeWithTag("charge-Rent").performScrollTo().assertTextContains("€900.00", substring = true)
    }

    @Test fun cancelAChange() {
        rule.onNodeWithTag("charge-Rent").performScrollTo().performClick()
        rule.onNodeWithTag("charge-amount").performTextReplacement("999")
        rule.onNodeWithTag("cancel").performClick()
        rule.onNodeWithTag("charge-Rent").performScrollTo().assertTextContains("€850.00", substring = true)
    }

    @Test fun deleteAChargeFromItsForm() {
        rule.onNodeWithTag("charge-Netflix").performScrollTo().performClick()
        rule.onNodeWithTag("delete").performScrollTo().performClick()
        rule.onNodeWithText("Delete").performClick()
        waitUntilGone("Netflix")
        assertEquals(5, model.state.value.charges.size)
    }

    @Test fun seeThePlannedSavings() {
        rule.onNodeWithTag("saver-Gold coins").performScrollTo().assertTextContains("€300.00", substring = true)
        rule.onNodeWithTag("saver-Savings account").assertTextContains("€200.00", substring = true)
        rule.onNodeWithText("€500.00").assertExists()
    }

    @Test fun everyTabOpens() {
        rule.onNodeWithTag("tab-Income").performClick()
        rule.onNodeWithTag("header-value").assertTextContains("€3,150.00")
        rule.onNodeWithTag("tab-Wealth").performClick()
        rule.onNodeWithTag("header-title").assertTextContains("Investments value")
        rule.onNode(hasTestTag("investment-MSCI World")).assertExists()
        rule.onNodeWithTag("tab-Trends").performClick()
        rule.onNodeWithTag("screen-title").assertTextContains("Trends")
    }

    @Test fun takeTheMonthsSnapshotAgain() {
        val before = model.state.value.snapshots.size
        rule.onNodeWithTag("snapshot-button").performClick()
        rule.onNodeWithTag("sheet-title").assertTextContains("Snapshot")
        rule.onNodeWithText("Replaces the snapshot taken on", substring = true).assertExists()
        rule.onNodeWithTag("snapshot-note").performTextInput("Checked")
        rule.onNodeWithTag("save").performClick()
        rule.waitUntil(5_000) { model.state.value.snapshots.last().note == "Checked" }
        assertEquals(before, model.state.value.snapshots.size)
    }
}

package com.example.budget.android.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.example.budget.android.ui.theme.palette
import com.example.budget.core.BudgetState
import com.example.budget.core.snapshots.Snapshot

/** A tab's screen: large title, toolbar actions, and a scrolling column of cards. */
@Composable
fun TabScreen(
    title: String,
    actions: @Composable () -> Unit = {},
    navigation: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Scaffold(
        containerColor = palette.background,
        topBar = {
            TopAppBar(
                title = { Text(title, fontWeight = FontWeight.Bold, fontSize = 28.sp, modifier = Modifier.testTag("screen-title")) },
                navigationIcon = { navigation?.invoke() },
                actions = { actions() },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = palette.background, titleContentColor = palette.ink),
            )
        },
    ) { padding ->
        Column(
            Modifier.padding(padding).fillMaxSize().verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp).padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            content = content,
        )
    }
}

/** The calendar button on every tab: opens the month's snapshot, and shows whether it's done. */
@Composable
fun SnapshotButton(state: BudgetState, nav: Nav) {
    val done = Snapshot.isTakenThisMonth(state.snapshots)
    TextButton(
        onClick = { nav.present(Sheet.Snapshot) },
        modifier = Modifier.testTag("snapshot-button").semantics {
            contentDescription = "Snapshot"
            stateDescription = if (done) "Taken this month" else "To take this month"
        },
    ) { Text(if (done) "📅✓" else "📅!", color = if (done) palette.ink else palette.accent, fontSize = 18.sp) }
}

/** A "+" button that opens a menu when there's more than one thing to add. */
@Composable
fun AddButton(vararg items: Pair<String, () -> Unit>) {
    var open by remember { mutableStateOf(false) }
    TextButton(
        onClick = { if (items.size == 1) items[0].second() else open = true },
        modifier = Modifier.testTag("add-button").semantics { contentDescription = "Add" },
    ) { Text("+", fontSize = 26.sp, color = palette.accent) }
    DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
        items.forEach { (label, action) ->
            DropdownMenuItem(text = { Text(label) }, onClick = { open = false; action() })
        }
    }
}

@Composable
fun BackButton(nav: Nav) {
    TextButton(onClick = { nav.back() }, modifier = Modifier.testTag("back")) { Text("‹ Back", color = palette.accent) }
}

/**
 * A form shown full screen over everything, like a sheet on iOS: Cancel on
 * the left, Save on the right (off until the form is valid).
 */
@Composable
fun FormSheet(
    title: String,
    onDismiss: () -> Unit,
    saveLabel: String = "Save",
    canSave: Boolean = true,
    onSave: (() -> Unit)?,
    cancelLabel: String? = "Cancel",
    content: @Composable ColumnScope.() -> Unit,
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        Scaffold(
            containerColor = palette.background,
            modifier = Modifier.imePadding(),
            topBar = {
                TopAppBar(
                    title = { Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag("sheet-title")) },
                    navigationIcon = {
                        if (cancelLabel != null) {
                            TextButton(onClick = onDismiss, modifier = Modifier.testTag("cancel")) { Text(cancelLabel) }
                        }
                    },
                    actions = {
                        if (onSave != null) {
                            TextButton(onClick = onSave, enabled = canSave, modifier = Modifier.testTag("save")) {
                                Text(saveLabel, fontWeight = FontWeight.Bold)
                            }
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = palette.background),
                )
            },
        ) { padding ->
            Column(
                Modifier.padding(padding).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
                content = content,
            )
        }
    }
}

/** A group of fields on a card, with an optional title and footer. */
@Composable
fun FormSection(title: String? = null, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (title != null) {
            Text(title.uppercase(), style = MaterialTheme.typography.labelMedium, color = palette.softInk,
                modifier = Modifier.padding(start = 6.dp))
        }
        BudgetCard {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
        }
        if (footer != null) {
            Text(footer, style = MaterialTheme.typography.bodySmall, color = palette.softInk,
                modifier = Modifier.padding(horizontal = 6.dp))
        }
    }
}

/** A label and its value on one line. */
@Composable
fun LabeledRow(label: String, value: String, valueColor: androidx.compose.ui.graphics.Color = palette.ink) {
    Row(Modifier.fillMaxWidth()) {
        Text(label, color = palette.ink, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(8.dp))
        Text(value, color = valueColor)
    }
}

/** A destructive button at the bottom of a form, asking first. */
@Composable
fun DeleteButton(label: String, confirmTitle: String, onDelete: () -> Unit) {
    var asking by remember { mutableStateOf(false) }
    TextButton(onClick = { asking = true }, modifier = Modifier.fillMaxWidth().testTag("delete")) {
        Text(label, color = palette.negative)
    }
    if (asking) ConfirmDelete(confirmTitle, onConfirm = onDelete, onDismiss = { asking = false })
}

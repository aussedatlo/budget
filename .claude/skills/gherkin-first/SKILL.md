---
name: gherkin-first
description: Use for any feature, behavior or UI change in the Budget app. Update the Gherkin plan first, then the UI, then the UI test.
---

# Gherkin first

1. **Plan.** Add or edit the scenario(s) in the Gherkin plan doc before touching code.
   Remove scenarios for behavior that goes away.
2. **UI.** Change the app in `Budget/` to match the scenarios exactly.
3. **Test.** One test per scenario in `BudgetUITests/`, under the matching
   `Feature` class (subclass of `BudgetUITestCase`), using the scenario's
   wording in `given` / `when` / `then` / `and` steps.
4. **Mark.** Tag each scenario that has a test `@covered` in the doc;
   drop the tag if its test is removed.

No Xcode in cloud containers: CI on the PR is the only build and test check.
In the PR description, list the scenarios added or changed.

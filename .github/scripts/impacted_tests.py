#!/usr/bin/env python3
"""Pick the UI test classes a pull request can break, from the files it changes.

Each app file is mapped to the test files that go through its screens. A
change to a file not listed below (models, shared code, the app setup, the
project, the test helpers) runs every test. Colors and the CI itself only
run a quick smoke test, and a change that can't reach the app (README,
other workflows, this file) runs none.

Prints, for $GITHUB_OUTPUT:
  classes=<test classes, space separated, or "all">
  shards=<JSON list of the test jobs to start, [] when nothing runs>

Usage: git diff --name-only BASE...HEAD | impacted_tests.py <tests-dir> <max-shards>
"""
import fnmatch
import json
import math
import re
import sys
from pathlib import Path

# App file -> test files that use its screens (in BudgetUITests/)
TESTS_FOR = {
    "Budget/Monthly/*": ["BudgetTabTests", "SnapshotTests"],
    "Budget/Shared/ConfettiView.swift": ["WealthTabTests"],
    "Budget/Shared/JarView.swift": ["BudgetTabTests"],  # removed, replaced by Mascots.swift
    "Budget/Shared/Mascots.swift": ["BudgetTabTests", "IncomeTabTests", "WealthTabTests"],
    "Budget/Income/IncomeView.swift": ["IncomeTabTests", "MoneyLentTests", "SettingsAndLaunchTests"],
    "Budget/Income/LendingViews.swift": ["MoneyLentTests", "IncomeTabTests", "SnapshotTests", "WealthTabTests"],
    "Budget/Investments/SavingsViews.swift": ["BudgetTabTests", "WealthTabTests", "TrendsTabTests"],
    "Budget/Investments/InvestmentForms.swift": ["WealthTabTests", "SnapshotTests"],
    "Budget/Investments/LoanViews.swift": ["WealthTabTests", "SnapshotTests"],
    "Budget/Investments/*": ["WealthTabTests", "TrendsTabTests"],
    "Budget/Stats/SnapshotView.swift": ["SnapshotTests", "TrendsTabTests"],
    "Budget/Stats/StatsView.swift": ["TrendsTabTests"],
    "Budget/App/SettingsView.swift": ["SettingsAndLaunchTests"],
}

# Files that can only break the look or the CI run, not what the tests check:
# a quick test is enough to show the app still starts and the CI still works
SMOKE_FOR = ["Budget/Shared/Theme.swift", "Budget/Assets.xcassets/*",
             ".github/workflows/e2e.yml", ".github/scripts/*"]
SMOKE = ["SettingsAndLaunchTests"]

# Files that never reach the app or the UI tests
UNRELATED = ["*.md", "docs/*", ".claude/*", ".github/workflows/ios.yml",
             ".github/scripts/screenshot_comment.py", ".github/scripts/impacted_tests.py",
             ".gitignore", "LICENSE*"]

tests_dir, max_shards = Path(sys.argv[1]), int(sys.argv[2])
changed = [line.strip() for line in sys.stdin if line.strip()]


def classes_in(test_file):
    return re.findall(r"^\s*(?:final\s+)?class\s+(\w+)\s*:", test_file.read_text(), re.M)


def test_files_for(path):
    """Test files to run for one changed file, or None for all of them."""
    if path.startswith(f"{tests_dir.name}/"):
        name = Path(path).stem
        if (tests_dir / f"{name}.swift").is_file() and name.endswith("Tests"):
            return [name]
        return None  # the base test case and helpers
    if any(fnmatch.fnmatch(path, pattern) for pattern in UNRELATED):
        return []
    for pattern, files in TESTS_FOR.items():  # first match wins
        if fnmatch.fnmatch(path, pattern):
            return files
    if any(fnmatch.fnmatch(path, pattern) for pattern in SMOKE_FOR):
        return SMOKE
    return None


files, everything = set(), False
for path in changed:
    found = test_files_for(path)
    print(f"{path}: {'all tests' if found is None else ', '.join(found) or 'no tests'}", file=sys.stderr)
    if found is None:
        everything = True
    else:
        files.update(found)

all_classes = [c for f in sorted(tests_dir.glob("*Tests.swift")) for c in classes_in(f)]
if everything:
    classes = all_classes
else:
    classes = [c for name in sorted(files) if (tests_dir / f"{name}.swift").is_file()
               for c in classes_in(tests_dir / f"{name}.swift")]

# About 3 test classes per job at least, so a small change starts fewer runners
shards = min(max_shards, math.ceil(len(classes) / 3))
print(f"{len(classes)} of {len(all_classes)} test classes, {shards} jobs", file=sys.stderr)
print(f"classes={'all' if everything else ' '.join(classes)}")
print(f"shards={json.dumps(list(range(1, shards + 1)))}")

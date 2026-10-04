#!/usr/bin/env python3
"""Print the `-only-testing` arguments of one shard of the UI tests.

The test classes are read from the sources, so a new class is picked up
without listing it anywhere. They are spread so that every shard takes
about the same time: by the durations of a previous run when a timings
file is given (see test_timings.py), otherwise by the number of tests.

Usage: shard_tests.py <tests-dir> <shard> <shards> [timings.json]   (shards count from 1)
With $TEST_CLASSES set (space separated, see impacted_tests.py), only
those classes are split; "all" or unset means every class.
"""
import json
import os
import re
import sys
from pathlib import Path

tests_dir, shard, shards = Path(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
timings_file = Path(sys.argv[4]) if len(sys.argv) > 4 else None
target = tests_dir.name

# Test count per class
classes = {}
for source in sorted(tests_dir.glob("*.swift")):
    current = None
    for line in source.read_text().splitlines():
        declared = re.match(r"\s*(?:final\s+)?class\s+(\w+)\s*:", line)
        if declared:
            current = declared.group(1)
        elif current and re.match(r"\s*func\s+test\w*\s*\(", line):
            classes[current] = classes.get(current, 0) + 1

only = os.environ.get("TEST_CLASSES", "all").split()
if only and only != ["all"]:
    classes = {name: tests for name, tests in classes.items() if name in only}

# Seconds per class from a previous run. A class it doesn't know (a new
# one) is guessed from its number of tests at the average time per test.
timings = {}
if timings_file and timings_file.is_file():
    timings = {name: secs for name, secs in json.loads(timings_file.read_text()).items()
               if name in classes and secs > 0}
if timings:
    per_test = sum(timings.values()) / sum(classes[name] for name in timings)
    weights = {name: timings.get(name, tests * per_test) for name, tests in classes.items()}
    unit = "s"
else:
    weights = dict(classes)
    unit = " tests"

# Heaviest classes first, each one to the shard with the lightest load so far
loads = [0] * shards
assigned = [[] for _ in range(shards)]
for name, weight in sorted(weights.items(), key=lambda item: (-item[1], item[0])):
    lightest = loads.index(min(loads))
    loads[lightest] += weight
    assigned[lightest].append(name)

mine = sorted(assigned[shard - 1])
if not mine:
    sys.exit(f"No test class for shard {shard} of {shards}")
print(f"Shard {shard}/{shards}: {loads[shard - 1]:.0f}{unit} in {', '.join(mine)}", file=sys.stderr)
print(" ".join(f"-only-testing:{target}/{name}" for name in mine))

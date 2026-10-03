#!/usr/bin/env python3
"""Print the `-only-testing` arguments of one shard of the UI tests.

The test classes are read from the sources, so a new class is picked up
without listing it anywhere. They are spread so that every shard runs
about the same number of tests.

Usage: shard_tests.py <tests-dir> <shard> <shards>      (shards count from 1)
"""
import re
import sys
from pathlib import Path

tests_dir, shard, shards = Path(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
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

# Largest classes first, each one to the shard with the fewest tests so far
loads = [0] * shards
assigned = [[] for _ in range(shards)]
for name, tests in sorted(classes.items(), key=lambda item: (-item[1], item[0])):
    lightest = loads.index(min(loads))
    loads[lightest] += tests
    assigned[lightest].append(name)

mine = sorted(assigned[shard - 1])
if not mine:
    sys.exit(f"No test class for shard {shard} of {shards}")
print(f"Shard {shard}/{shards}: {loads[shard - 1]} tests in {', '.join(mine)}", file=sys.stderr)
print(" ".join(f"-only-testing:{target}/{name}" for name in mine))

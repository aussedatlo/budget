#!/usr/bin/env python3
"""Print how long each UI test class took, as JSON {"Class": seconds}.

Reads the output of `xcrun xcresulttool get test-results tests --format json`.
The CI keeps these timings so the next run can split the tests by duration.

Usage: xcrun xcresulttool get test-results tests --path X.xcresult --format json | test_timings.py
"""
import json
import re
import sys


def seconds(node):
    if isinstance(node.get("durationInSeconds"), (int, float)):
        return float(node["durationInSeconds"])
    # Older Xcode only gives text such as "1m 5s" or "0.53s"
    units = {"h": 3600, "m": 60, "s": 1}
    return sum(float(value) * units[unit]
               for value, unit in re.findall(r"([\d.]+)\s*(h|m|s)\b", node.get("duration", "")))


timings = {}


def walk(nodes, suite=None):
    for node in nodes:
        kind = node.get("nodeType")
        if kind == "Test Suite":
            walk(node.get("children", []), node.get("name"))
        elif kind == "Test Case" and suite:
            timings[suite] = round(timings.get(suite, 0) + seconds(node), 1)
        else:
            walk(node.get("children", []), suite)


walk(json.load(sys.stdin).get("testNodes", []))
print(json.dumps(timings, indent=1, sort_keys=True))

#!/usr/bin/env python3
"""Print the UDID of an available simulator on the newest iOS runtime.

Usage: xcrun simctl list devices available -j | pick_simulator.py iPhone|iPad
"""
import json
import re
import sys

kind = sys.argv[1]
devices = json.load(sys.stdin)["devices"]


def runtime_version(key):
    match = re.search(r"\.iOS-([\d-]+)$", key)
    return [int(x) for x in match.group(1).split("-")] if match else None


# Prefer regular-size models: no SE / mini, and no Max for screenshots.
def preference(device):
    name = device["name"]
    if any(word in name for word in ("SE", "mini", "Max")):
        return 2
    if kind == "iPhone" and "Pro" in name:
        return 0
    if kind == "iPad" and ("Pro 11" in name or "Air 11" in name):
        return 0
    return 1


runtimes = sorted((k for k in devices if runtime_version(k)), key=runtime_version, reverse=True)
for runtime in runtimes:
    candidates = [d for d in devices[runtime] if d["name"].startswith(kind) and d.get("isAvailable", True)]
    if candidates:
        device = min(candidates, key=preference)
        print(f"{device['udid']} {device['name']} ({runtime.rsplit('.', 1)[-1]})", file=sys.stderr)
        print(device["udid"])
        sys.exit(0)

sys.exit(f"No available {kind} simulator found")

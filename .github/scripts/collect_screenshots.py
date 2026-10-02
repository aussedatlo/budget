#!/usr/bin/env python3
"""Copy screenshots exported by `xcresulttool export attachments` to
<output>/<name>.png, using the attachment names given in the UI tests.

Usage: collect_screenshots.py <exported-attachments-dir> <output-dir>
"""
import json
import re
import shutil
import sys
from pathlib import Path

source, output = Path(sys.argv[1]), Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)

manifest = json.loads((source / "manifest.json").read_text())
failures = 0
for test in manifest:
    for attachment in test.get("attachments", []):
        exported = source / attachment["exportedFileName"]
        if exported.suffix.lower() not in (".png", ".jpg", ".jpeg"):
            continue
        # Xcode suggests "<name>_<index>_<UUID>.png"
        suggested = attachment.get("suggestedHumanReadableName", exported.name)
        match = re.match(r"(\d{2}-[\w-]+?)_\d+_", suggested)
        if match:
            name = match.group(1)
        else:
            failures += 1
            name = f"zz-failure-{failures}"
        shutil.copy(exported, output / f"{name}{exported.suffix.lower()}")
        print(f"{suggested} -> {name}")

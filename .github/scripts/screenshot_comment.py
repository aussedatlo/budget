#!/usr/bin/env python3
"""Build the PR comment (markdown) showing the UI test screenshots.

Usage: screenshot_comment.py <screenshots-dir> <base-url> <tests-result> <run-url>
<screenshots-dir> contains one folder per device (iPhone, iPad).
"""
import sys
from pathlib import Path

root, base_url, result, run_url = Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
widths = {"iPhone": 220, "iPad": 360}
per_row = {"iPhone": 4, "iPad": 2}

status = "✅ passed" if result == "success" else f"❌ {result}"
lines = [
    "<!-- e2e-screenshots -->",
    "## 📱 E2E screenshots",
    "",
    f"UI tests {status} · [workflow run]({run_url})",
    "",
]

for device_dir in sorted(root.iterdir(), reverse=True):  # iPhone before iPad
    if not device_dir.is_dir():
        continue
    device = device_dir.name
    images = sorted(device_dir.glob("*.png"))
    gifs = sorted(device_dir.glob("*.gif"))
    if gifs:
        lines.append(f"<details open><summary><b>{device}</b> animations</summary>\n")
        lines.append("<table>\n<tr>")
        for gif in gifs:
            url = f"{base_url}/{device}/{gif.name}?raw=true"
            label = gif.stem.split("-", 1)[-1].replace("-", " ")
            lines.append(f'<td align="center"><img src="{url}" width="240" alt="{gif.stem}"><br><sub>{label}</sub></td>')
        lines.append("</tr>\n</table>\n</details>\n")
    lines.append(f"<details open><summary><b>{device}</b> ({len(images)} screens)</summary>\n")
    if not images:
        lines.append("_No screenshots (the tests probably failed to build or launch)._")
    lines.append("<table>")
    count = per_row.get(device, 3)
    for i in range(0, len(images), count):
        lines.append("<tr>")
        for image in images[i:i + count]:
            url = f"{base_url}/{device}/{image.name}?raw=true"
            label = image.stem.split("-", 1)[-1].replace("-", " ")
            lines.append(
                f'<td align="center"><img src="{url}" width="{widths.get(device, 250)}" alt="{image.stem}">'
                f"<br><sub>{label}</sub></td>"
            )
        lines.append("</tr>")
    lines.append("</table>\n</details>\n")

print("\n".join(lines))

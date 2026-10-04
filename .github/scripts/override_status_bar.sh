#!/usr/bin/env bash
# Gives every booted simulator a clean, consistent status bar for the
# screenshots, including the clones that parallel testing boots later.
# Runs until the job ends.
seen=" "
while true; do
  for udid in $(xcrun simctl list devices booted -j |
                python3 -c 'import json, sys; print(" ".join(d["udid"] for ds in json.load(sys.stdin)["devices"].values() for d in ds))'); do
    case "$seen" in *" $udid "*) continue ;; esac
    xcrun simctl status_bar "$udid" override --time 9:41 \
      --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 && seen="$seen$udid "
  done
  sleep 2
done

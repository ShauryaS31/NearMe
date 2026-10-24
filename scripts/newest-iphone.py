#!/usr/bin/env python3
"""Print the newest available iPhone UDID from simctl's devices JSON."""

import json
import re
import sys


def version_key(value):
    return tuple(int(part) for part in re.findall(r"\d+", value))


candidates = []
for runtime, devices in json.load(sys.stdin).get("devices", {}).items():
    match = re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not match:
        continue
    version = version_key(match.group(1))
    # Normalize trailing zeroes so 26.5 and 26.5.0 compare equally.
    version = (version + (0, 0, 0))[:3]
    for device in devices:
        name = device.get("name", "")
        if name.startswith("iPhone") and device.get("isAvailable", False):
            candidates.append((version, version_key(name), name, device["udid"]))

if not candidates:
    sys.exit("No available iPhone simulator. Install an iOS 26.5 or newer runtime in Xcode Settings > Components.")

print(max(candidates)[-1])

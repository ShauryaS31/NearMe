#!/usr/bin/env python3
"""Print the devicectl identifier of a connected, paired iPhone.

Usage: python3 scripts/connected-iphone.py <devicectl list devices --json-output file>
Prefers a cable connection over Wi-Fi.
"""

import json
import sys

with open(sys.argv[1]) as handle:
    devices = json.load(handle).get("result", {}).get("devices", [])

candidates = []
for device in devices:
    hardware = device.get("hardwareProperties", {})
    connection = device.get("connectionProperties", {})
    if hardware.get("deviceType") != "iPhone" or connection.get("pairingState") != "paired":
        continue
    if connection.get("tunnelState") == "unavailable":
        continue
    wired = connection.get("transportType") == "wired"
    candidates.append((wired, device.get("deviceProperties", {}).get("name", ""), device["identifier"]))

if not candidates:
    sys.exit("No connected iPhone. Connect it by cable, unlock it, tap Trust, and turn on "
             "Settings > Privacy & Security > Developer Mode.")

print(max(candidates)[-1])

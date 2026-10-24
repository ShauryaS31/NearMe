#!/usr/bin/env python3
"""Print the devicectl identifier of a connected, paired, physical iPhone.

Usage: python3 scripts/connected-iphone.py <devicectl json> [simctl json] [--device=<name or id>]
  devicectl json: output of `xcrun devicectl list devices --json-output <file>`
  simctl json:    output of `xcrun simctl list devices -j` (optional); any device whose id
                  matches a simulator UDID is ignored, even if devicectl lists it
  --device=...:   prefer this device (name, case-insensitive, or identifier or UDID)
Simulators are never chosen. Prefers a cable connection over Wi-Fi.
"""

import json
import sys

args = [a for a in sys.argv[1:] if not a.startswith("--device=")]
wanted = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--device=")), "").strip()

with open(args[0]) as handle:
    devices = json.load(handle).get("result", {}).get("devices", [])

simulator_ids = set()
if len(args) > 1:
    with open(args[1]) as handle:
        for runtime_devices in json.load(handle).get("devices", {}).values():
            simulator_ids.update(d.get("udid", "").upper() for d in runtime_devices)


def is_physical_iphone(device):
    hardware = device.get("hardwareProperties", {})
    connection = device.get("connectionProperties", {})
    platform = hardware.get("platform", "")
    ids = {device.get("identifier", "").upper(), hardware.get("udid", "").upper()} - {""}
    if ids & simulator_ids:
        return False
    if hardware.get("reality", "physical") != "physical":
        return False
    if "simulator" in platform.lower() or (platform and platform != "iOS"):
        return False
    if hardware.get("deviceType") != "iPhone" or connection.get("pairingState") != "paired":
        return False
    # Connected now: an active tunnel or a live transport (cable or local network).
    return connection.get("tunnelState") == "connected" or connection.get("transportType") in ("wired", "localNetwork")


candidates = []
for device in devices:
    if not is_physical_iphone(device):
        continue
    name = device.get("deviceProperties", {}).get("name", "")
    ids = {device.get("identifier", ""), device.get("hardwareProperties", {}).get("udid", "")}
    wired = device.get("connectionProperties", {}).get("transportType") == "wired"
    candidates.append({"id": device["identifier"], "name": name, "ids": ids, "wired": wired})

if not candidates:
    sys.exit("No connected iPhone. Connect it by cable, unlock it, tap Trust, and turn on "
             "Settings > Privacy & Security > Developer Mode.")

if wanted:
    chosen = [c for c in candidates if c["name"].lower() == wanted.lower() or wanted in c["ids"]]
    if not chosen:
        names = ", ".join(c["name"] or c["id"] for c in candidates)
        sys.exit(f"No connected iPhone matches --device={wanted}. Connected: {names}")
    pick = chosen[0]
else:
    pick = max(candidates, key=lambda c: (c["wired"], c["name"]))

print(f"Using iPhone: {pick['name'] or pick['id']}", file=sys.stderr)
print(pick["id"])

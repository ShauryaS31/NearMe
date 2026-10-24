#!/usr/bin/env python3
"""Tests for scripts/connected-iphone.py with devicectl and simctl JSON fixtures."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "connected-iphone.py"


def device(identifier, name, *, reality="physical", platform="iOS", transport="wired",
           tunnel="connected", paired="paired", kind="iPhone", udid=None):
    hardware = {"deviceType": kind, "platform": platform, "udid": udid or identifier}
    if reality is not None:
        hardware["reality"] = reality
    return {"identifier": identifier, "deviceProperties": {"name": name}, "hardwareProperties": hardware,
            "connectionProperties": {"pairingState": paired, "tunnelState": tunnel, "transportType": transport}}


class ConnectedIPhoneTests(unittest.TestCase):
    def run_script(self, devices, simulators=None, *extra):
        with tempfile.TemporaryDirectory() as folder:
            devicectl = Path(folder) / "devices.json"
            devicectl.write_text(json.dumps({"result": {"devices": devices}}))
            args = [sys.executable, str(SCRIPT), str(devicectl)]
            if simulators is not None:
                simctl = Path(folder) / "sims.json"
                simctl.write_text(json.dumps({"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-1":
                                                          [{"udid": u, "name": "iPhone Duo"} for u in simulators]}}))
                args.append(str(simctl))
            args.extend(extra)
            return subprocess.run(args, capture_output=True, text=True)

    def test_virtual_device_is_ignored(self):
        result = self.run_script([device("SIM-1", "iPhone Duo", reality="virtual"), device("PHONE-1", "Shaurya iPhone")])
        self.assertEqual(result.stdout.strip(), "PHONE-1")

    def test_simulator_platform_is_ignored(self):
        result = self.run_script([device("SIM-1", "iPhone Duo", platform="iOS Simulator")])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")

    def test_simulator_udid_is_ignored_even_without_reality_field(self):
        result = self.run_script([device("SIM-1", "iPhone Duo", reality=None), device("PHONE-1", "Phone")],
                                 simulators=["sim-1"])
        self.assertEqual(result.stdout.strip(), "PHONE-1")

    def test_disconnected_and_unpaired_are_ignored(self):
        result = self.run_script([device("A", "Old", tunnel="unavailable", transport=None),
                                  device("B", "Unpaired", paired="unpaired")])
        self.assertNotEqual(result.returncode, 0)

    def test_wired_preferred_over_wifi(self):
        result = self.run_script([device("WIFI", "Wifi phone", transport="localNetwork"), device("CABLE", "Cable phone")])
        self.assertEqual(result.stdout.strip(), "CABLE")

    def test_device_option_picks_by_name_or_id(self):
        devices = [device("CABLE", "Cable phone"), device("WIFI", "Mum's iPhone", transport="localNetwork")]
        self.assertEqual(self.run_script(devices, None, "--device=mum's iphone").stdout.strip(), "WIFI")
        self.assertEqual(self.run_script(devices, None, "--device=WIFI").stdout.strip(), "WIFI")
        missing = self.run_script(devices, None, "--device=Nope")
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("Cable phone", missing.stderr)


if __name__ == "__main__":
    unittest.main()

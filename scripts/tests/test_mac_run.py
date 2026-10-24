"""Exercise mac-run.sh with mocked Apple tools; no Xcode or simulator required.

Run: python3 scripts/tests/test_mac_run.py
"""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
MOCK = r'''#!/usr/bin/env bash
set -eu
tool="$(basename "$0")"
echo "$tool $*" >> "$TRACE"
case "$tool" in
  git) echo "Unexpected git operation" >&2; exit 90 ;;
  xcodegen)
    [[ "${FAIL:-}" != generation ]] || exit 2
    mkdir -p NearMe.xcodeproj
    touch NearMe.xcodeproj/project.pbxproj ;;
  xcodebuild)
    [[ "${FAIL:-}" != build ]] || exit 2
    echo '** BUILD SUCCEEDED **' ;;
  xcrun)
    case "$1 $2" in
      'simctl list')
        [[ "${FAIL:-}" != list ]] || { echo 'list failed' >&2; exit 2; }
        cat devices.json ;;
      'simctl boot')
        [[ "${FAIL:-}" != boot ]] || { echo 'boot failed' >&2; exit 2; } ;;
      'simctl bootstatus')
        [[ "${FAIL:-}" != bootstatus ]] || { echo 'bootstatus failed' >&2; exit 2; } ;;
    esac ;;
esac
'''


class MacRunTests(unittest.TestCase):
    def setUp(self):
        # Keep all fixtures inside the workspace; never touch real Apple tools/git.
        (ROOT / "build").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="mac-run-test-", dir=ROOT / "build")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ("scripts", "NearMe", "Shared", "NearMeTests", "bin"):
            (self.root / folder).mkdir()
        for name in ("mac-run.sh", "newest-iphone.py"):
            shutil.copyfile(ROOT / "scripts" / name, self.root / "scripts" / name)
        (self.root / "project.yml").write_text("name: NearMe\n")
        for name in ("git", "xcodegen", "xcodebuild", "xcrun", "open"):
            path = self.root / "bin" / name
            path.write_text(MOCK, newline="\n")
            path.chmod(0o755)
        python = self.root / "bin" / "python3"
        python.write_text(
            "#!/usr/bin/env bash\nexec " + shlex.quote(Path(sys.executable).as_posix()) + ' "$@"\n',
            newline="\n",
        )
        python.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.root / "bin") + os.pathsep + os.environ["PATH"],
                        TRACE=(self.root / "trace").as_posix())
        self.devices(booted=True)

    def devices(self, booted=False, empty=False):
        devices = [] if empty else [
            {"name": "iPhone 16", "udid": "older", "isAvailable": True,
             "state": "Booted" if booted else "Shutdown"},
            {"name": "iPhone 17", "udid": "newer", "isAvailable": True, "state": "Shutdown"},
        ]
        (self.root / "devices.json").write_text(json.dumps({
            "devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-5": devices}
        }))

    def run_mode(self, mode="quick", fail="", succeeds=True):
        (self.root / "trace").write_text("")
        args = [shutil.which("bash"), "scripts/mac-run.sh", mode]
        if mode != "quick":
            args.append("--current")
        result = subprocess.run(args, cwd=self.root, env=dict(self.env, FAIL=fail),
                                capture_output=True, text=True)
        trace = (self.root / "trace").read_text()
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Finished in ", result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn("simctl install", trace)
            self.assertNotIn("simctl launch", trace)
        self.assertNotIn("git ", trace)
        return trace, result

    def test_quick_cache_and_booted_reuse(self):
        trace, _ = self.run_mode()
        self.assertIn("xcodegen", trace)
        self.assertIn("-destination id=older -derivedDataPath build", trace)
        self.assertIn("simctl install older", trace)
        self.assertIn("simctl launch older au.nearme.ios", trace)
        self.assertNotIn("simctl boot ", trace)
        self.assertNotIn(" clean", trace)
        self.assertTrue((self.root / "build/.xcodegen-hash").is_file())
        trace, _ = self.run_mode()
        self.assertNotIn("xcodegen", trace)

    def test_generation_inputs_and_missing_project(self):
        self.run_mode()
        for folder in ("NearMe", "Shared", "NearMeTests"):
            path = self.root / folder / "Example.swift"
            path.write_text("// added\n")
            self.assertIn("xcodegen", self.run_mode()[0])
            path.write_text("// content edit needs only incremental build\n")
            self.assertNotIn("xcodegen", self.run_mode()[0])
            renamed = path.with_name("Renamed.swift")
            path.rename(renamed)
            self.assertIn("xcodegen", self.run_mode()[0])
            renamed.unlink()
            self.assertIn("xcodegen", self.run_mode()[0])
        (self.root / "project.yml").write_text("name: Changed\n")
        self.assertIn("xcodegen", self.run_mode()[0])
        (self.root / "NearMe.xcodeproj/project.pbxproj").unlink()
        self.assertIn("xcodegen", self.run_mode()[0])

    def test_quick_boots_when_none_running(self):
        self.devices()
        trace, _ = self.run_mode()
        self.assertIn("simctl boot newer", trace)
        self.assertIn("simctl launch newer", trace)

    def test_simulator_failures_stop_all_simulator_modes(self):
        for mode in ("quick", "sim", "test", "eval"):
            for failure in ("list", "boot", "bootstatus", "empty", "empty-id"):
                with self.subTest(mode=mode, failure=failure):
                    self.devices(empty=failure == "empty")
                    picker = self.root / "scripts/newest-iphone.py"
                    original = picker.read_text()
                    if failure == "empty-id":
                        picker.write_text("# Successful exit with no id\n")
                    try:
                        trace, _ = self.run_mode(mode, fail=failure, succeeds=False)
                        self.assertNotIn("xcodebuild", trace)
                    finally:
                        picker.write_text(original)

    def test_failures_do_not_cache_or_launch(self):
        self.run_mode(fail="generation", succeeds=False)
        self.assertFalse((self.root / "build/.xcodegen-hash").exists())
        self.run_mode(fail="build", succeeds=False)

    def test_existing_modes_keep_test_and_eval_arguments(self):
        for mode in ("sim", "test", "eval"):
            trace, _ = self.run_mode(mode)
            self.assertIn("xcodegen", trace)
            self.assertIn("-destination id=newer", trace)
            if mode in ("test", "eval"):
                self.assertIn("CODE_SIGNING_ALLOWED=NO test", trace)
            if mode == "eval":
                self.assertIn("-only-testing:NearMeTests/ModelEvalTests", trace)


if __name__ == "__main__":
    unittest.main(verbosity=2)

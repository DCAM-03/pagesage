"""Exercise Android CI readiness with actual Bash and an isolated fake SDK."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class AndroidBootTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pagesage-boot-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.sdk = self.root / "sdk with spaces"
        (self.sdk / "platform-tools").mkdir(parents=True)
        self.bash = shutil.which("bash")
        if os.name == "nt":
            self.bash = str(Path(shutil.which("git")).parent.parent / "bin/bash.exe")
        adb = self.sdk / "platform-tools/adb"
        adb.write_text(r'''#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == version ]]; then echo 'SDK adb test version'; exit 0; fi
if [[ "$1" == devices ]]; then echo 'emulator-5554 offline'; exit 0; fi
[[ "$1" == -s && "$2" == emulator-5554 ]] || exit 99
shift 2
if [[ "$1" == get-state ]]; then
  case "$BOOT_TEST_MODE" in
    offline) echo 'device is offline' >&2; echo offline; exit 1 ;;
    recover)
      if [[ ! -f "$RUNNER_TEMP/queried" ]]; then
        touch "$RUNNER_TEMP/queried"
        echo 'temporary adb connection failure' >&2
        exit 1
      fi ;;
  esac
  printf 'device\r\n'; exit 0
fi
if [[ "$*" == 'shell getprop sys.boot_completed' ]]; then
  if [[ "$BOOT_TEST_MODE" == never_boot ]]; then echo 0; else printf '1\r\n'; fi
  exit 0
fi
if [[ "$*" == 'shell pm path android' ]]; then
  if [[ "$BOOT_TEST_MODE" == package_unavailable ]]; then
    echo 'package service not available' >&2; exit 1
  fi
  echo 'package:/system/framework/framework-res.apk'; exit 0
fi
exit 98
''', encoding="utf-8", newline="\n")
        adb.chmod(0o755)

    def run_probe(self, mode, timeout=1):
        env = {**os.environ, "BOOT_TEST_MODE": mode}
        return subprocess.run([
            self.bash, "--noprofile", "--norc", "-c",
            'sdk="$1"; temporary="$2"; '
            'if command -v cygpath >/dev/null; then '
            'sdk="$(cygpath -u "$sdk")"; temporary="$(cygpath -u "$temporary")"; fi; '
            'export ANDROID_HOME="$sdk" RUNNER_TEMP="$temporary"; '
            'exec bash "$3" emulator-5554 "$4"',
            "_", self.sdk.as_posix(), self.root.as_posix(),
            (REPO / "tool/wait_android_boot.sh").as_posix(), str(timeout),
        ], env=env, capture_output=True, text=True, timeout=30)

    def test_crlf_boot_property_and_ready_package_manager_pass(self):
        result = self.run_probe("ready")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Android ready:", result.stdout)

    def test_transient_adb_failure_is_retried(self):
        result = self.run_probe("recover", timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Android ready:", result.stdout)
        self.assertIn("temporary adb connection failure", (self.root / "pagesage-adb.log").read_text())

    def test_emulator_boot_log_does_not_replace_adb_readiness(self):
        (self.root / "pagesage-emulator.log").write_text("Boot completed in 82196 ms\n")
        result = self.run_probe("offline")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Android readiness timed out", result.stderr)
        self.assertIn("emulator-5554 offline", result.stdout)
        self.assertIn("device is offline", result.stdout)

    def test_connected_device_with_unfinished_boot_fails(self):
        result = self.run_probe("never_boot")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sys.boot_completed=0", result.stderr)

    def test_boot_property_without_android_services_is_not_ready(self):
        result = self.run_probe("package_unavailable")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("package=unavailable", result.stderr)
        self.assertIn("package service not available", result.stdout)


if __name__ == "__main__":
    unittest.main()

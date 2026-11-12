"""Behavior checks for platform archives, checksums and draft-only uploads."""

import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("package_platform", REPO / "tool/package_platform.py")
PACKAGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACKAGE)


class DistributionTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pagesage-packaging-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / "output 中文"
        self.output.mkdir()
        self.bundle = self.root / "bundle 空格"
        for name in PACKAGE.WINDOWS_REQUIRED:
            path = self.bundle / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())

    def apk(self, omit=None):
        names = [f"lib/{abi}/{lib}.so" for abi in ("arm64-v8a", "armeabi-v7a", "x86_64")
                 for lib in ("libapp", "libflutter", "libsqlite3")]
        names += ["assets/flutter_assets/assets/fonts/LXGWWenKaiLite-Regular.ttf",
                  "assets/flutter_assets/assets/images/brand/app-icon-source.svg",
                  "assets/mlkit-google-ocr-models/model.bin"]
        apk = self.root / "source.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            for name in names:
                if name != omit:
                    archive.writestr(name, name)
        return apk

    def test_windows_keeps_complete_tree_and_unicode_paths(self):
        extra = self.bundle / "data/flutter_assets/中文 空格.txt"
        extra.write_text("extra asset", encoding="utf-8")
        (self.bundle / "optional.dll").write_bytes(b"plugin")
        (self.bundle / "pagesage.pdb").write_bytes(b"symbols")
        destination = PACKAGE.windows(self.bundle, self.output, "0.1.0+1")
        with zipfile.ZipFile(destination) as archive:
            self.assertEqual(archive.read("pagesage/data/flutter_assets/中文 空格.txt"), b"extra asset")
            self.assertEqual(archive.read("pagesage/optional.dll"), b"plugin")
            self.assertNotIn("pagesage/pagesage.pdb", archive.namelist())
            for required in PACKAGE.WINDOWS_REQUIRED:
                self.assertIn(f"pagesage/{required}", archive.namelist())
        PACKAGE.verify(self.output)

    def test_windows_rejects_missing_plugin_before_writing(self):
        (self.bundle / "flutter_secure_storage_windows_plugin.dll").unlink()
        with self.assertRaisesRegex(ValueError, "Incomplete Windows bundle"):
            PACKAGE.windows(self.bundle, self.output, "0.1.0+1")
        self.assertEqual(list(self.output.iterdir()), [])

    def test_windows_rejects_host_native_asset_manifest(self):
        (self.bundle / "native_assets.json").write_text("host paths")
        with self.assertRaisesRegex(ValueError, "native_assets.json"):
            PACKAGE.windows(self.bundle, self.output, "0.1.0+1")

    def test_checksum_rejects_tampering_and_empty_download(self):
        with self.assertRaisesRegex(ValueError, "No checksums"):
            PACKAGE.verify(self.output)
        path = PACKAGE.windows(self.bundle, self.output, "0.1.0+1")
        path.write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
            PACKAGE.verify(self.output)

    def test_checksum_rejects_parent_path(self):
        (self.output / "bad.sha256").write_text("0  ../outside\n")
        with self.assertRaisesRegex(ValueError, "filename"):
            PACKAGE.verify(self.output)

    def test_android_test_name_and_signed_aab_are_distinct(self):
        apk = self.apk()
        PACKAGE.android(apk, None, self.output, "0.1.0+1", False)
        self.assertTrue((self.output / "pagesage-0.1.0+1-android-test.apk").exists())
        aab = self.root / "source.aab"
        with zipfile.ZipFile(aab, "w") as archive:
            archive.writestr("base/manifest/AndroidManifest.xml", b"manifest")
        PACKAGE.android(apk, aab, self.output, "0.1.0+1", True)
        self.assertTrue((self.output / "pagesage-0.1.0+1-android.apk").exists())
        self.assertTrue((self.output / "pagesage-0.1.0+1-android.aab").exists())
        PACKAGE.verify(self.output)

    def test_android_rejects_missing_abi_model_and_aab(self):
        for missing in ("lib/arm64-v8a/libsqlite3.so", "assets/mlkit-google-ocr-models/model.bin"):
            with self.subTest(missing=missing), self.assertRaisesRegex(ValueError, "APK missing"):
                PACKAGE.android(self.apk(missing), None, self.output, "0.1.0+1", False)
        with self.assertRaisesRegex(ValueError, "requires an AAB"):
            PACKAGE.android(self.apk(), None, self.output, "0.1.0+1", True)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_invalid_version_cannot_escape_output(self):
        (self.root / "pubspec.yaml").write_text("version: ../../escape\n")
        with patch.object(PACKAGE, "REPO", self.root), self.assertRaises(ValueError):
            PACKAGE.app_version()


class DraftReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pagesage-draft-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls.txt"
        self.asset = self.root / "asset with spaces.zip"
        self.asset.write_bytes(b"tested-package")
        self.bash = shutil.which("bash")
        if os.name == "nt":
            self.bash = str(Path(shutil.which("git")).parent.parent / "bin/bash.exe")
        self.assertTrue(self.bash and Path(self.bash).is_file(), "Git Bash/bash is required")
        gh = self.bin / "gh"
        gh.write_text('''#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "$GH_TEST_LOG"
case "$2" in
  view)
    case "$GH_TEST_STATE" in
      missing) exit 1 ;;
      published) echo false ;;
      *) echo true ;;
    esac ;;
  create) exit 0 ;;
  upload) test "${GH_TEST_UPLOAD_FAIL:-false}" != true ;;
  *) exit 99 ;;
esac
''', encoding="utf-8", newline="\n")
        gh.chmod(0o755)

    def run_release(self, state, *, missing=False, upload_fail=False):
        script = REPO / "tool/publish_draft_release.sh"
        env = {**os.environ, "GH_TEST_STATE": state, "GH_TEST_LOG": self.log.as_posix(),
               "GH_TEST_UPLOAD_FAIL": str(upload_fail).lower()}
        asset = self.root / "missing.zip" if missing else self.asset
        return subprocess.run([
            self.bash, "--noprofile", "--norc", "-c",
            'stub="$1"; if command -v cygpath >/dev/null; then stub="$(cygpath -u "$stub")"; fi; '
            'export PATH="$stub:$PATH"; exec bash "$2" v0.1.0-beta.1 "$3"',
            "_", self.bin.as_posix(), script.as_posix(), asset.as_posix(),
        ], env=env, capture_output=True, text=True)

    def test_missing_release_creates_draft_then_uploads(self):
        result = self.run_release("missing")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.log.read_text().splitlines()
        self.assertEqual(len(calls), 3)
        self.assertIn("--draft --verify-tag", calls[1])
        self.assertIn("--prerelease", calls[1])
        self.assertIn("upload v0.1.0-beta.1 --clobber", calls[2])

    def test_existing_draft_is_reused(self):
        result = self.run_release("draft")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("create", self.log.read_text())

    def test_published_release_is_never_modified(self):
        result = self.run_release("published")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("upload", self.log.read_text())
        self.assertNotIn("create", self.log.read_text())

    def test_missing_asset_does_not_call_github(self):
        self.assertNotEqual(self.run_release("missing", missing=True).returncode, 0)
        self.assertFalse(self.log.exists())

    def test_upload_failure_is_not_reported_as_success(self):
        self.assertNotEqual(self.run_release("draft", upload_fail=True).returncode, 0)


if __name__ == "__main__":
    unittest.main()

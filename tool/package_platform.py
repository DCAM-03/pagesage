"""Package complete Windows bundles or verified Android outputs, using stdlib."""

import argparse
import hashlib
from pathlib import Path
import re
import shutil
import zipfile

REPO = Path(__file__).resolve().parent.parent
WINDOWS_REQUIRED = (
    "pagesage.exe", "flutter_windows.dll", "sqlite3.dll",
    "file_selector_windows_plugin.dll", "flutter_secure_storage_windows_plugin.dll",
    "url_launcher_windows_plugin.dll", "data/icudtl.dat", "data/app.so",
    "data/flutter_assets/NOTICES.Z",
    "data/flutter_assets/assets/fonts/LXGWWenKaiLite-Regular.ttf",
    "data/flutter_assets/assets/images/brand/app-icon-source.svg",
)


def app_version():
    match = re.search(r"^version:\s*(\S+)\s*$", (REPO / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
    if not match or not re.fullmatch(r"[0-9][0-9A-Za-z.+-]*", match[1]):
        raise ValueError("Invalid pubspec version")
    return match[1]


def checksum(path):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    path.with_name(path.name + ".sha256").write_text(f"{digest}  {path.name}\n", encoding="ascii")


def verify(output):
    manifests = list(output.glob("*.sha256"))
    if not manifests:
        raise ValueError("No checksums to verify")
    for manifest in manifests:
        digest, name = manifest.read_text(encoding="ascii").strip().split("  ", 1)
        if Path(name).name != name or "/" in name or "\\" in name:
            raise ValueError("Checksum path must be a filename")
        if hashlib.sha256((output / name).read_bytes()).hexdigest() != digest:
            raise ValueError(f"Checksum mismatch: {name}")


def windows(bundle, output, version):
    for relative in WINDOWS_REQUIRED:
        if not (bundle / relative).is_file():
            raise ValueError(f"Incomplete Windows bundle: {relative}")
    files = [file for file in bundle.rglob("*") if file.is_file()]
    # A test-generated native asset manifest contains build-host paths.
    if any(file.name == "native_assets.json" for file in files):
        raise ValueError("Windows bundle contains a test native_assets.json; clean and rebuild")
    destination = output / f"pagesage-{version}-windows-x86_64.zip"
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(files):
            if file.suffix.lower() != ".pdb":
                archive.write(file, f"pagesage/{file.relative_to(bundle).as_posix()}")
    checksum(destination)
    return destination


def android(apk, aab, output, version, signed):
    with zipfile.ZipFile(apk) as archive:
        names = set(archive.namelist())
        for abi in ("arm64-v8a", "armeabi-v7a", "x86_64"):
            for library in ("libapp.so", "libflutter.so", "libsqlite3.so"):
                if f"lib/{abi}/{library}" not in names:
                    raise ValueError(f"APK missing {abi}/{library}")
        for name in (
            "assets/flutter_assets/assets/fonts/LXGWWenKaiLite-Regular.ttf",
            "assets/flutter_assets/assets/images/brand/app-icon-source.svg",
        ):
            if name not in names:
                raise ValueError(f"APK missing {name}")
        if not any(name.startswith("assets/mlkit-google-ocr-models/") for name in names):
            raise ValueError("APK missing offline OCR models")
    if signed:
        if aab is None:
            raise ValueError("Signed distribution requires an AAB")
        with zipfile.ZipFile(aab) as archive:
            if "base/manifest/AndroidManifest.xml" not in archive.namelist():
                raise ValueError("Invalid Android App Bundle")
    suffix = "android" if signed else "android-test"
    for source, extension in [(apk, "apk"), *([(aab, "aab")] if signed else [])]:
        destination = output / f"pagesage-{version}-{suffix}.{extension}"
        shutil.copyfile(source, destination)
        checksum(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=["windows", "android", "verify"])
    parser.add_argument("--bundle", type=Path, default=REPO / "build/windows/x64/runner/Release")
    parser.add_argument("--apk", type=Path, default=REPO / "build/app/outputs/flutter-apk/app-release.apk")
    parser.add_argument("--aab", type=Path)
    parser.add_argument("--signed", action="store_true", help="Signing has already been checked by apksigner/jarsigner")
    parser.add_argument("--output", type=Path, default=REPO / "dist")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.target == "windows":
        print(windows(args.bundle, args.output, app_version()))
    elif args.target == "android":
        android(args.apk, args.aab, args.output, app_version(), args.signed)
    verify(args.output)


if __name__ == "__main__":
    main()

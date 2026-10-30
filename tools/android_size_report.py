"""Record Android artifact sizes and optional bundletool download estimates.

Sizes are bytes. AAB upload size, selected APK size, and estimated download
size are separate metrics; none is an actual Google Play download measurement.
Only pass a device spec without device IDs or private signing information.
"""

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import subprocess
import zipfile


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run(command):
    return subprocess.check_output(command, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--bundletool", type=Path)
    parser.add_argument("--device-spec", type=Path)
    parser.add_argument("--flutter-version-file", type=Path)
    parser.add_argument("--source-revision", help="Known CI revision for an existing external artifact")
    args = parser.parse_args()
    if bool(args.bundletool) != bool(args.device_spec):
        parser.error("--bundletool and --device-spec must be supplied together")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bundle = args.bundle.resolve()
    with zipfile.ZipFile(bundle) as archive:
        icons = [entry for entry in archive.infolist()
                 if entry.filename.endswith("/ic_launcher.png")]
        icon_sizes = {entry.filename: entry.file_size for entry in icons}
    report = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_revision": args.source_revision or run(["git", "rev-parse", "HEAD"]),
        "source_status": None if args.source_revision else run(
            ["git", "status", "--porcelain", "--untracked-files=normal"]),
        "lockfile_sha256": None if args.source_revision else digest(Path("pubspec.lock")),
        "bundle": {"name": bundle.name, "bytes": bundle.stat().st_size,
                   "sha256": digest(bundle)},
        "launcher_png_uncompressed_bytes": sum(icon_sizes.values()),
        "launcher_pngs": icon_sizes,
        "notes": "bundletool estimates are not measured Google Play transfer sizes",
    }
    if args.flutter_version_file:
        report["flutter"] = json.loads(args.flutter_version_file.read_text(encoding="utf-8-sig"))
    if args.bundletool:
        tool = args.bundletool.resolve()
        spec = args.device_spec.resolve()
        apks = args.output.with_suffix(".apks").resolve()
        java = ["java", "-jar", str(tool)]
        subprocess.run(java + ["build-apks", f"--bundle={bundle}",
                              f"--output={apks}", f"--device-spec={spec}",
                              "--overwrite"], check=True)
        estimate = run(java + ["get-size", "total", f"--apks={apks}",
                               f"--device-spec={spec}"])
        rows = list(csv.DictReader(io.StringIO(estimate)))
        if len(rows) != 1 or not {"MIN", "MAX"}.issubset(rows[0]):
            raise SystemExit(f"Unexpected bundletool size output: {estimate}")
        with zipfile.ZipFile(apks) as archive:
            selected_apks = {entry.filename: entry.file_size
                             for entry in archive.infolist()
                             if entry.filename.endswith(".apk")}
        report.update({
            "bundletool": {"version": run(java + ["version"]), "sha256": digest(tool)},
            "device_spec": json.loads(spec.read_text(encoding="utf-8-sig")),
            "selected_apk_bytes": sum(selected_apks.values()),
            "selected_apks": selected_apks,
            "apks_sha256": digest(apks),
            "estimated_download_bytes": {"min": int(rows[0]["MIN"]),
                                         "max": int(rows[0]["MAX"])},
        })
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "report": str(args.output),
        "source_revision": report["source_revision"],
        "bundle": report["bundle"],
        "launcher_png_uncompressed_bytes": report["launcher_png_uncompressed_bytes"],
        "selected_apk_bytes": report.get("selected_apk_bytes"),
        "estimated_download_bytes": report.get("estimated_download_bytes"),
    }, indent=2))


if __name__ == "__main__":
    main()

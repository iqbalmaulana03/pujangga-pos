"""Run the finite-payment suite on Android and reconcile its SQLite evidence."""

import argparse
import datetime
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import tarfile

PACKAGE = "com.pujanggapos.pujangga_pos.pr80e2e"


def collect_evidence(adb, serial, output, revision):
    archive = subprocess.run(
        [adb, "-s", serial, "exec-out", "run-as", PACKAGE,
         "tar", "-cf", "-", "-C", "cache", "pr80-evidence"],
        capture_output=True, check=True, timeout=30,
    ).stdout
    (output / "device-evidence.tar").write_bytes(archive)
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        bundle.extractall(output, filter="data")
    directory = output / "pr80-evidence"
    result = json.loads((directory / "result.json").read_text(encoding="utf-8"))
    assert result["status"] == "passed"
    assert result["revision"] == revision
    assert result["package"] == PACKAGE
    with sqlite3.connect(
        (directory / "verified.sqlite").resolve().as_uri() + "?mode=ro", uri=True,
    ) as connection:
        connection.row_factory = sqlite3.Row
        assert connection.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        headers = [dict(row) for row in connection.execute("SELECT * FROM sales_transactions")]
        assert len(headers) == 1
        assert connection.execute("SELECT COUNT(*) FROM sales_transaction_items").fetchone()[0] == 2
        for key, expected in {
            "subtotal_amount": 20000, "discount_amount": 2000, "tax_amount": 1800,
            "total_amount": 19800, "paid_amount": 25000, "change_amount": 5200,
            "commission_amount": 1800,
        }.items():
            assert headers[0][key] == expected, key
        for query, expected in [
            ("SELECT stock_qty FROM items WHERE item_type='product'", 9),
            ("SELECT amount FROM expenses WHERE source_type='commission'", 1800),
            ("SELECT qty_after FROM stock_movements ORDER BY id DESC LIMIT 1", 9),
        ]:
            assert connection.execute(query).fetchone()[0] == expected
        for filename in result["backup_files"]:
            assert Path(filename).name == filename
            payload = json.loads((directory / filename).read_text(encoding="utf-8"))
            if payload["format"] == "pujangga_pos_encrypted_backup":
                assert "tables" not in payload and payload["ciphertext"]
                continue
            for table, rows in payload["tables"].items():
                assert table.replace("_", "").isalnum()
                stored = [dict(row) for row in connection.execute(
                    'SELECT * FROM "' + table + '" ORDER BY id',
                )]
                assert stored == rows, table
                for row in stored:
                    assert all(not isinstance(value, float) or math.isfinite(value)
                               for value in row.values())
    result["apk_sha256"] = hashlib.sha256(
        Path("build/app/outputs/flutter-apk/app-debug.apk").read_bytes(),
    ).hexdigest()
    result["host_sqlite_reconciliation"] = "passed"
    result["verified_at_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    result["artifacts_sha256"] = {
        file.name: hashlib.sha256(file.read_bytes()).hexdigest()
        for file in sorted(directory.iterdir()) if file.is_file()
    }
    (output / "verified-result.json").write_text(
        json.dumps(result, indent=2), encoding="utf-8",
    )
    print("E2E_HOST_RECONCILIATION: passed", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, help="ADB serial from adb devices -l")
    parser.add_argument("--flutter", default="flutter", help="Flutter executable, including .bat on Windows")
    parser.add_argument("--adb", default="adb", help="ADB executable")
    parser.add_argument("--output", type=Path, default=Path("build/e2e-80"))
    args = parser.parse_args()
    if sys.flags.optimize:
        parser.error("Run without -O: evidence assertions must remain enabled.")
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    os.chdir(Path(__file__).resolve().parent.parent)
    flutter = shutil.which(args.flutter)
    adb = shutil.which(args.adb)
    if not flutter or not adb:
        parser.error("Flutter and ADB must exist; specify --flutter and --adb if needed.")
    state = subprocess.run([adb, "-s", args.device, "get-state"],
                           capture_output=True, text=True, check=True, timeout=15)
    if state.stdout.strip() != "device":
        parser.error("The requested ADB device must be online and authorized.")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    args.output.mkdir(parents=True, exist_ok=True)
    # Prevent a stale result from a previous run appearing to be current evidence.
    verified = args.output / "verified-result.json"
    if verified.exists():
        verified.unlink()
    env = os.environ.copy()
    env["PUJANGGA_FINITE_E2E"] = "1"
    # Never use Flutter's default uninstall cleanup: on a first build the
    # pre-build package identity can still refer to the release namespace.
    command = [flutter, "test", "--no-pub", "--no-uninstall", "-d", args.device,
               "--dart-define=E2E_SOURCE_REVISION=" + revision,
               "--reporter", "expanded", "integration_test/finite_payment_test.dart"]
    print("E2E_START: " + datetime.datetime.now(datetime.timezone.utc).isoformat(), flush=True)
    screenshots = set()
    native_input = False
    with (args.output / "run.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True,
                                   encoding="utf-8", errors="replace")
        try:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if any(marker in line for marker in [
                    "E2E_", "All tests passed", "Some tests failed", "FAILURE:",
                    "Running Gradle", "Built ", "Installing ", "Expected:", "Actual:",
                ]):
                    print(line.rstrip(), flush=True)
                match = re.search(r"E2E_CAPTURE: ([a-z-]+)", line)
                if match:
                    screenshot = subprocess.run(
                        [adb, "-s", args.device, "exec-out", "screencap", "-p"],
                        capture_output=True, check=True, timeout=20,
                    ).stdout
                    assert screenshot.startswith(b"\x89PNG")
                    (args.output / (match.group(1) + ".png")).write_bytes(screenshot)
                    screenshots.add(match.group(1))
                if "E2E_ADB_INPUT: 25000" in line:
                    subprocess.run([adb, "-s", args.device, "shell", "input", "text", "25000"],
                                   capture_output=True, check=True, timeout=20)
                    native_input = True
            code = process.wait()
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=30)
    (args.output / "exit-code.txt").write_text(str(code), encoding="utf-8")
    if code:
        return code
    assert native_input and screenshots == {"invalid-infinity", "normal-receipt"}
    collect_evidence(adb, args.device, args.output, revision)
    print("E2E_EXIT: 0", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

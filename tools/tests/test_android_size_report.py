import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

from tools.android_size_report import lockfile_fingerprints


class AndroidSizeReportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pujangga-size-report-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.symbols = self.root / "symbols"
        self.symbols.mkdir()
        self.bundle = self.root / "fixture.aab"
        self.output = self.root / "report.json"

    def report(self, entries, symbols):
        """Run the CLI with synthetic bundle/symbol fixtures in an isolated directory."""
        with zipfile.ZipFile(self.bundle, "w") as archive:
            for entry in entries:
                archive.writestr(entry, b"synthetic fixture")
        for name in symbols:
            (self.symbols / name).write_bytes(b"synthetic symbols")
        return subprocess.run(
            [sys.executable, "tools/android_size_report.py",
             "--bundle", str(self.bundle), "--output", str(self.output),
             "--source-revision", "synthetic-test",
             "--dart-symbols", str(self.symbols)],
            capture_output=True, text=True,
        )

    def test_partial_symbols_fail_before_report_is_written(self):
        result = self.report(
            ["base/lib/armeabi-v7a/libapp.so", "base/lib/arm64-v8a/libapp.so",
             "base/lib/x86_64/libapp.so"],
            ["app.android-arm.symbols"],
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("arm64-v8a (app.android-arm64.symbols)", result.stderr)
        self.assertIn("x86_64 (app.android-x64.symbols)", result.stderr)
        self.assertFalse(self.output.exists())

    def test_all_dart_abis_have_checksums_in_report(self):
        names = ["app.android-arm.symbols", "app.android-arm64.symbols",
                 "app.android-x64.symbols"]
        result = self.report(
            ["base/lib/armeabi-v7a/libapp.so", "base/lib/arm64-v8a/libapp.so",
             "base/lib/x86_64/libapp.so"], names,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.output.read_text())
        self.assertEqual(set(report["dart_debug_symbols"]), set(names))

    def test_plugin_only_abi_does_not_require_dart_symbols(self):
        result = self.report(
            ["base/lib/arm64-v8a/libapp.so", "base/lib/x86_64/libscanner.so"],
            ["app.android-arm64.symbols"],
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_empty_symbol_directory_is_rejected(self):
        result = self.report(["base/lib/arm64-v8a/libapp.so"], [])
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.output.exists())

    def test_unknown_dart_abi_is_rejected(self):
        result = self.report(["base/lib/unknown/libapp.so"], ["app.android-arm.symbols"])
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unsupported Dart ABI", result.stderr)

    def test_lockfile_retains_raw_hash_and_normalizes_only_crlf(self):
        path = self.root / "pubspec.lock"
        lf = b"packages:\n  intl: 0.20.3\n"
        path.write_bytes(lf)
        linux = lockfile_fingerprints(path)
        crlf = lf.replace(b"\n", b"\r\n")
        path.write_bytes(crlf)
        windows = lockfile_fingerprints(path)
        self.assertEqual(windows["lockfile_sha256"], hashlib.sha256(crlf).hexdigest())
        self.assertNotEqual(windows["lockfile_sha256"], linux["lockfile_sha256"])
        self.assertEqual(windows["lockfile_lf_sha256"], linux["lockfile_lf_sha256"])


if __name__ == "__main__":
    unittest.main()

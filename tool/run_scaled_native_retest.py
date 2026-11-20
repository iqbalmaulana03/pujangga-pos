"""Run the persistence regression suite on disposable Android SQLite databases."""
import argparse
import datetime
from decimal import Decimal
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--device', required=True)
parser.add_argument('--flutter', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
if sys.flags.optimize:
    parser.error('Assertions must remain enabled')
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
OUT = (ROOT / args.output).resolve()
if not OUT.is_relative_to(ROOT / 'build') or OUT.exists():
    parser.error('Use a fresh output directory inside build/')
OUT.mkdir(parents=True)
PACKAGE = 'com.pujanggapos.pujangga_pos.pr82e2e'
TARGET = 'integration_test/scaled_legacy_retest_test.dart'
ADB = [shutil.which('adb'), '-s', args.device]
FLUTTER = args.flutter

def read(args, **kw):
    return subprocess.check_output(args, timeout=60, **kw)

inventory = ADB + ['shell', 'pm', 'list', 'packages', 'com.pujanggapos.pujangga_pos']
before = read(inventory, text=True).splitlines()
assert 'package:' + PACKAGE not in before, 'Never overwrite an existing package'
revision = read(['git', 'rev-parse', 'HEAD'], text=True).strip()
fingerprints = {}
for path in list((ROOT / 'lib').rglob('*.dart')) + [ROOT / 'pubspec.yaml', ROOT / 'pubspec.lock']:
    relative = path.relative_to(ROOT).as_posix()
    actual = path.read_bytes().replace(b'\r\n', b'\n')
    assert actual == read(['git', 'show', revision + ':' + relative]).replace(b'\r\n', b'\n')
    fingerprints[relative] = hashlib.sha256(actual).hexdigest()
unit_test = 'test/scaled_transaction_persistence_test.dart'
assert (ROOT / unit_test).read_bytes().replace(b'\r\n', b'\n') == read(
    ['git', 'show', revision + ':' + unit_test]).replace(b'\r\n', b'\n')
subprocess.run([sys.executable, str(ROOT / 'tool/generate_scaled_native_retest.py')], check=True)
dart = Path(FLUTTER).with_name('dart.bat' if os.name == 'nt' else 'dart')
subprocess.run([str(dart), 'format', TARGET], check=True)
env = {k: v for k, v in os.environ.items() if not (k.startswith('PUJANGGA_') and k.endswith('_E2E'))}
env['PUJANGGA_SCALED_E2E'] = '1'
define = '--dart-define=E2E_SOURCE_REVISION=' + revision
print('PR82_LEGACY_BUILD_START: ' + revision, flush=True)
with (OUT / 'build.log').open('w', encoding='utf-8') as log:
    subprocess.run([FLUTTER, 'build', 'apk', '--debug', '--no-pub', '--target', TARGET, define],
                   env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
apk = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
sdk_line = next(line for line in (ROOT / 'android/local.properties').read_text().splitlines()
                if line.startswith('sdk.dir='))
sdk = Path(sdk_line.split('=', 1)[1].replace('\\\\', '\\').replace('\\:', ':'))
aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe' if os.name == 'nt' else '*/aapt'))[-1]
manifest = read([str(aapt), 'dump', 'badging', str(apk)], text=True)
assert "package: name='" + PACKAGE + "'" in manifest
apk_hash = hashlib.sha256(apk.read_bytes()).hexdigest()
with (OUT / 'run.log').open('w', encoding='utf-8') as log:
    process = subprocess.Popen([FLUTTER, 'test', '--no-pub', '--no-uninstall', '-d',
        args.device, '--reporter', 'expanded', define, TARGET],
        env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding='utf-8', errors='replace')
    try:
        for line in process.stdout:
            log.write(line)
            log.flush()
            if any(x in line for x in ['PR82_', '[E]', 'Expected:', 'Actual:', 'All tests passed', 'Error:']):
                print(line.rstrip(), flush=True)
        code = process.wait()
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=30)
assert code == 0, code
apk_hash = hashlib.sha256(apk.read_bytes()).hexdigest()
manifest = read([str(aapt), 'dump', 'badging', str(apk)], text=True)
assert "package: name='" + PACKAGE + "'" in manifest
archive = read(ADB + ['exec-out', 'run-as', PACKAGE, 'tar', '-cf', '-', '-C', 'cache', 'pr82-legacy-evidence'])
(OUT / 'device-evidence.tar').write_bytes(archive)
with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
    bundle.extractall(OUT, filter='data')
data = OUT / 'pr82-legacy-evidence'
result = json.loads((data / 'result.json').read_text())
assert result['revision'] == revision and result['status'] == 'passed'
assert len(result['tests']) == 19, result['tests']
assert len(result['snapshots']) == 38
legacy = [s for s in result['snapshots'] if s['test'].startswith('restored legacy ledger')]
assert len(legacy) == 12
for snapshot in result['snapshots']:
    file = (data / snapshot['file']).resolve()
    assert file.parent == data.resolve()
    with sqlite3.connect(file.as_uri() + '?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert not db.execute('PRAGMA foreign_key_check').fetchall()
        for table, expected in snapshot['tables'].items():
            assert table.replace('_', '').isalnum()
            actual = [dict(row) for row in db.execute('SELECT * FROM "' + table + '" ORDER BY id')]
            assert actual == expected, (snapshot['test'], table)
        if snapshot in legacy:
            movements = [dict(row) for row in db.execute('SELECT * FROM stock_movements ORDER BY id')]
            assert len(movements) == 2
            assert movements[0]['qty_after'] == movements[1]['qty_before'] == 0.1995
            for row in movements:
                assert Decimal(str(row['qty_before'])) + Decimal(str(row['qty_change'])) == Decimal(str(row['qty_after']))
            assert db.execute('SELECT stock_qty FROM items').fetchone()[0] == movements[-1]['qty_after']
subprocess.run(ADB + ['uninstall', PACKAGE], capture_output=True, check=True, timeout=45)
after = read(inventory, text=True).splitlines()
assert set(before) == set(after)
summary = {k: v for k, v in result.items() if k != 'snapshots'}
summary.update({'native_database_snapshots_verified': len(result['snapshots']),
    'independent_sqlite_and_decimal_reconciliation': 'passed',
    'source_files_verified': len(fingerprints), 'apk_sha256': apk_hash,
    'harness_sha256': hashlib.sha256((ROOT / TARGET).read_bytes()).hexdigest(),
    'host_verified_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'package_removed': True, 'existing_packages_preserved': True, 'inventory_after': after})
(OUT / 'verified-result.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
shutil.copyfile(ROOT / TARGET, OUT / 'scaled_legacy_retest_test.dart')
(ROOT / TARGET).unlink()  # The generator refuses to replace an existing file.
print('PR82_LEGACY_VERIFIED: native cases and 38 SQLite snapshots reconciled; package removed', flush=True)

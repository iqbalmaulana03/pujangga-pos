"""PR82: isolated real-Android UI exercise and independent SQLite reconciliation."""
import argparse
import datetime
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import tarfile

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

PACKAGE = 'com.pujanggapos.pujangga_pos.pr82e2e'
TARGET = 'integration_test/scaled_arithmetic_e2e_test.dart'


def reconcile(output, revision):
    root = output / 'pr82-evidence'
    result = json.loads((root / 'result.json').read_text(encoding='utf-8'))
    assert result['revision'] == revision and result['package'] == PACKAGE
    assert result['status'] == 'passed' and len(result['events']) == 33
    for currency, factor in [('USD', 1), ('SGD', 1), ('IDR', 100)]:
        plain = json.loads((root / f'{currency}-plaintext.json').read_text(encoding='utf-8'))
        envelope = json.loads((root / f'{currency}-encrypted.json').read_text(encoding='utf-8'))
        import base64
        decode = lambda field: base64.b64decode(envelope[field], validate=True)
        assert envelope['format'] == 'pujangga_pos_encrypted_backup'
        assert envelope['iterations'] == 600000
        key = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=decode('salt'),
            iterations=600000).derive(b'PR82 Synthetic backup password')
        decrypted = AESGCM(key).decrypt(decode('nonce'), decode('ciphertext') + decode('tag'),
            b'pujangga_pos_encrypted_backup:1:AES-256-GCM:PBKDF2-HMAC-SHA256:600000')
        assert json.loads(decrypted)['tables'] == plain['tables']
        for suffix in ['verified', 'restored']:
            file = (root / f'{currency}-{suffix}.sqlite').resolve()
            with sqlite3.connect(file.as_uri() + '?mode=ro', uri=True) as db:
                db.row_factory = sqlite3.Row
                assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
                assert db.execute('PRAGMA foreign_key_check').fetchall() == []
                for table, expected in plain['tables'].items():
                    assert table.replace('_', '').isalnum()
                    rows = [dict(row) for row in db.execute('SELECT * FROM "' + table + '" ORDER BY id')]
                    assert rows == expected, (currency, suffix, table)
                stock = {row['name']: row['stock_qty'] for row in db.execute('SELECT * FROM items')}
                assert stock == {'PR82 Berat': 0, 'PR82 Sen': 17, 'PR82 Jasa': 0, 'PR82 Bagian': 0}
                headers = [dict(row) for row in db.execute('SELECT * FROM sales_transactions ORDER BY id')]
                assert len(headers) == 7
                for row in headers[:2]:
                    assert row['total_amount'] == 0.3 * factor
                    assert row['paid_amount'] == 0.3 * factor
                    assert row['change_amount'] == 0
                assert [row['total_amount'] for row in headers[2:5]] == [0.1 * factor] * 3
                mixed = headers[5]
                for key, expected in {'subtotal_amount': 0.6 * factor, 'discount_amount': 0.1 * factor,
                    'tax_amount': 0.05 * factor, 'total_amount': 55 if currency == 'IDR' else 0.55,
                    'paid_amount': 55 if currency == 'IDR' else 0.55, 'change_amount': 0,
                    'commission_amount': 0.03 * factor, 'status': 'voided'}.items():
                    assert mixed[key] == expected, (currency, key)
                assert db.execute('SELECT COUNT(*) FROM expenses').fetchone()[0] == 0
                legacy = headers[-1]
                expected_legacy = 0.1 * factor * 0.15
                assert legacy['total_amount'] == expected_legacy
                detail = db.execute('SELECT * FROM sales_transaction_items WHERE transaction_id = ?',
                    [legacy['id']]).fetchone()
                assert detail['line_total'] == expected_legacy and detail['qty'] == 0.15
                movements = [dict(row) for row in db.execute('SELECT * FROM stock_movements ORDER BY id')]
                assert len(movements) == 30
                # Exact thousandths across every stock movement, independently of Dart.
                from decimal import Decimal
                for row in movements:
                    assert Decimal(str(row['qty_before'])) + Decimal(str(row['qty_change'])) == Decimal(str(row['qty_after']))
    result['independent_crypto_and_sqlite_reconciliation'] = 'passed'
    result['verified_at_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--output', default='build/pr82-e2e')
    args = parser.parse_args()
    if sys.flags.optimize:
        parser.error('Assertions must remain enabled')
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    output = root / args.output
    output.mkdir(parents=True, exist_ok=True)
    if (output / 'verified-result.json').exists():
        parser.error('Refuse an output directory with stale success evidence')
    adb = [shutil.which('adb'), '-s', args.device]
    def read(command, **kwargs):
        return subprocess.check_output(command, timeout=40, **kwargs)
    inventory_command = adb + ['shell', 'pm', 'list', 'packages', 'com.pujanggapos.pujangga_pos']
    before = read(inventory_command, text=True)
    if 'package:' + PACKAGE in before.splitlines():
        parser.error('Dedicated test package already exists: never overwrite existing data')
    (output / 'inventory-before.txt').write_text(before, encoding='utf-8')
    revision = read(['git', 'rev-parse', 'HEAD'], text=True).strip()
    # Verify the entire shipped Dart implementation and lockfile match the PR.
    fingerprints = {}
    for file in list((root / 'lib').rglob('*.dart')) + [root / 'pubspec.lock', root / 'pubspec.yaml']:
        relative = file.relative_to(root).as_posix()
        committed = read(['git', 'show', revision + ':' + relative])
        actual = file.read_bytes().replace(b'\r\n', b'\n')
        assert actual == committed.replace(b'\r\n', b'\n'), relative
        fingerprints[relative] = hashlib.sha256(actual).hexdigest()
    (output / 'source-fingerprints.json').write_text(json.dumps(fingerprints, indent=2), encoding='utf-8')
    env = {key: value for key, value in os.environ.items()
           if not (key.startswith('PUJANGGA_') and key.endswith('_E2E'))}
    env['PUJANGGA_SCALED_E2E'] = '1'
    define = '--dart-define=E2E_SOURCE_REVISION=' + revision
    print('PR82_BUILD_START: ' + revision, flush=True)
    with (output / 'build.log').open('w', encoding='utf-8') as log:
        subprocess.run([args.flutter, 'build', 'apk', '--debug', '--no-pub', '--target', TARGET, define],
            env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    sdk_line = next(line for line in (root / 'android/local.properties').read_text().splitlines()
        if line.startswith('sdk.dir='))
    sdk = Path(sdk_line.split('=', 1)[1].replace('\\\\', '\\').replace('\\:', ':'))
    aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
    manifest = read([str(aapt), 'dump', 'badging', str(apk)], text=True)
    assert "package: name='" + PACKAGE + "'" in manifest
    (output / 'apk-package.txt').write_text(manifest.splitlines()[0], encoding='utf-8')
    print('PR82_APK_ID_VERIFIED: ' + PACKAGE, flush=True)
    command = [args.flutter, 'test', '--no-pub', '--no-uninstall', '-d', args.device,
        '--reporter', 'expanded', define, TARGET]
    screenshots = set()
    native_input = False
    with (output / 'run.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
        try:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if any(marker in line for marker in ['PR82_', 'All tests passed', 'Some tests failed',
                    '[E]', 'Expected:', 'Actual:', 'Installing ', 'Built ', 'Error:']):
                    print(line.rstrip(), flush=True)
                match = re.search(r'PR82_CAPTURE: ([a-z-]+)', line)
                if match:
                    activity = read(adb + ['shell', 'dumpsys', 'activity', 'activities'], text=True)
                    assert any(PACKAGE in row for row in activity.splitlines()
                        if 'mResumedActivity' in row or 'topResumedActivity' in row)
                    screenshot = read(adb + ['exec-out', 'screencap', '-p'])
                    assert screenshot.startswith(b'\x89PNG')
                    (output / (match[1] + '.png')).write_bytes(screenshot)
                    screenshots.add(match[1])
                if 'PR82_ADB_INPUT: 0.30' in line:
                    subprocess.run(adb + ['shell', 'input', 'text', '0.30'], capture_output=True,
                        check=True, timeout=20)
                    native_input = True
            code = process.wait()
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=30)
    (output / 'exit-code.txt').write_text(str(code), encoding='utf-8')
    if code:
        return code
    assert native_input and len(screenshots) == 18, screenshots
    archive = read(adb + ['exec-out', 'run-as', PACKAGE, 'tar', '-cf', '-', '-C', 'cache', 'pr82-evidence'])
    (output / 'device-evidence.tar').write_bytes(archive)
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        bundle.extractall(output, filter='data')
    result = reconcile(output, revision)
    result['apk_sha256'] = hashlib.sha256(apk.read_bytes()).hexdigest()
    result['harness_sha256'] = hashlib.sha256((root / TARGET).read_bytes()).hexdigest()
    result['source_files_verified'] = len(fingerprints)
    result['native_adb_payment_input'] = '0.30'
    result['screenshots'] = sorted(screenshots)
    (output / 'verified-result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print('PR82_INDEPENDENT_RECONCILIATION: passed', flush=True)
    # Only this newly created namespace is owned by this run. Pull evidence first.
    subprocess.run(adb + ['uninstall', PACKAGE], capture_output=True, check=True, timeout=40)
    after = read(inventory_command, text=True)
    assert set(before.splitlines()) == set(after.splitlines())
    (output / 'cleanup.json').write_text(json.dumps({'test_package_removed': True,
        'preexisting_package_inventory_unchanged': True,
        'after': after.splitlines()}, indent=2), encoding='utf-8')
    print('PR82_CLEANUP: package removed; existing namespaces preserved', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())

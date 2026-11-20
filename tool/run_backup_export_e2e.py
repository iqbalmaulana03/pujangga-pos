"""PR81 Android backup export contract, with independent artifact reconciliation."""
import argparse
import base64
import datetime
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

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

PACKAGE = 'com.pujanggapos.pujangga_pos.pr81e2e'
TARGET = 'integration_test/backup_export_contract_e2e_test.dart'


def reconcile(output, revision):
    evidence = output / 'pr81-contract-evidence'
    result = json.loads((evidence / 'result.json').read_text())
    assert result['status'] == 'passed'
    assert result['revision'] == revision
    assert result['package'] == PACKAGE
    assert result['large_rows'] > 50000
    assert result['large_plaintext_bytes'] < 20 * 1024 * 1024
    plain = json.loads((evidence / 'plaintext.json').read_text())
    envelope = json.loads((evidence / 'encrypted.json').read_text())
    assert envelope['format'] == 'pujangga_pos_encrypted_backup'
    assert envelope['iterations'] == 600000
    decode = lambda name: base64.b64decode(envelope[name], validate=True)
    key = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32,
                    salt=decode('salt'), iterations=600000).derive(b'Synthetic PR81 export password')
    raw = AESGCM(key).decrypt(decode('nonce'), decode('ciphertext') + decode('tag'),
        b'pujangga_pos_encrypted_backup:1:AES-256-GCM:PBKDF2-HMAC-SHA256:600000')
    encrypted = json.loads(raw)
    assert plain['tables'] == encrypted['tables']
    assert plain['assets'] == encrypted['assets']
    assert base64.b64decode(plain['assets']['business_logo']['data_base64']) == (evidence / 'logo.png').read_bytes()
    with sqlite3.connect((evidence / 'restored.sqlite').resolve().as_uri() + '?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert db.execute('PRAGMA foreign_key_check').fetchall() == []
        for table, expected in plain['tables'].items():
            assert table.replace('_', '').isalnum()
            actual = [dict(row) for row in db.execute('SELECT * FROM "' + table + '" ORDER BY id')]
            if table == 'business_profile':
                for row in actual:
                    row['logo_path'] = None
            assert actual == expected, table
    assert len(result['events']) == 20, result['events']
    result['independent_crypto_and_sqlite_reconciliation'] = 'passed'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--output', default='build/pr81-e2e/contract')
    args = parser.parse_args()
    if sys.flags.optimize:
        parser.error('Assertions must remain enabled; do not use python -O')
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    output = root / args.output
    output.mkdir(parents=True, exist_ok=True)
    if (output / 'verified-result.json').exists():
        parser.error('Refuse a reused output directory containing previous success evidence')
    adb = [shutil.which('adb'), '-s', args.device]
    def run(command, **kwargs):
        return subprocess.check_output(command, timeout=30, **kwargs)
    before = run(adb + ['shell', 'pm', 'list', 'packages', 'com.pujanggapos.pujangga_pos'], text=True)
    if 'package:' + PACKAGE in before.splitlines():
        parser.error('Test package already exists; refusing to overwrite it')
    (output / 'inventory-before.txt').write_text(before)
    revision = run(['git', 'rev-parse', 'HEAD'], text=True).strip()
    env = {key: value for key, value in os.environ.items()
           if not (key.startswith('PUJANGGA_') and key.endswith('_E2E'))}
    env['PUJANGGA_BACKUP_CONTRACT_E2E'] = '1'
    define = '--dart-define=E2E_SOURCE_REVISION=' + revision
    with (output / 'build.log').open('w', encoding='utf-8') as log:
        print('PR81_BUILD_START', flush=True)
        subprocess.run([args.flutter, 'build', 'apk', '--debug', '--no-pub', '--target', TARGET, define],
                       env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    sdk_line = next(line for line in (root / 'android/local.properties').read_text().splitlines()
                    if line.startswith('sdk.dir='))
    sdk = Path(sdk_line.split('=', 1)[1].replace('\\\\', '\\').replace('\\:', ':'))
    aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
    manifest = run([str(aapt), 'dump', 'badging', str(apk)], text=True)
    assert "package: name='" + PACKAGE + "'" in manifest
    (output / 'apk-package.txt').write_text(manifest.splitlines()[0])
    print('PR81_APK_ID_VERIFIED', flush=True)
    command = [args.flutter, 'test', '--no-pub', '--no-uninstall', '-d', args.device,
               '--reporter', 'expanded', define, TARGET]
    with (output / 'run.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
        try:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if any(marker in line for marker in ['PR81_', 'All tests passed', 'Some tests failed',
                    '[E]', 'Expected:', 'Actual:', 'Installing ', 'Built ']):
                    print(line.rstrip(), flush=True)
            code = process.wait()
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=30)
    (output / 'exit-code.txt').write_text(str(code))
    after = run(adb + ['shell', 'pm', 'list', 'packages', 'com.pujanggapos.pujangga_pos'], text=True)
    (output / 'inventory-after.txt').write_text(after)
    assert set(before.splitlines()).issubset(after.splitlines())
    if code:
        return code
    archive = run(adb + ['exec-out', 'run-as', PACKAGE, 'tar', '-cf', '-', '-C', 'cache', 'pr81-contract-evidence'])
    (output / 'device-evidence.tar').write_bytes(archive)
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        bundle.extractall(output, filter='data')
    result = reconcile(output, revision)
    result['apk_sha256'] = hashlib.sha256(apk.read_bytes()).hexdigest()
    result['harness_sha256'] = hashlib.sha256((root / TARGET).read_bytes()).hexdigest()
    result['verified_at_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (output / 'verified-result.json').write_text(json.dumps(result, indent=2))
    print('PR81_INDEPENDENT_RECONCILIATION: passed', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())

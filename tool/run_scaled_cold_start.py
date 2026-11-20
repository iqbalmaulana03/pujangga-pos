"""Cold-process Android proof using the SQLite snapshot from the UI E2E run."""
import argparse
import base64
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import time

PACKAGE = 'com.pujanggapos.pujangga_pos.pr82e2e'
TARGET = 'integration_test/scaled_cold_start_app.dart'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--evidence', required=True)
    parser.add_argument('--resume-prepared', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    output = root / args.evidence
    result = json.loads((output / 'verified-result.json').read_text(encoding='utf-8'))
    assert result['status'] == 'passed'
    revision = result['revision']
    adb = [shutil.which('adb'), '-s', args.device]
    def read(command, **kwargs):
        return subprocess.check_output(command, timeout=45, **kwargs)
    inventory = adb + ['shell', 'pm', 'list', 'packages', 'com.pujanggapos.pujangga_pos']
    before = read(inventory, text=True)
    if args.resume_prepared:
        initial = json.loads((output / 'cleanup.json').read_text(encoding='utf-8'))['after']
        assert set(before.splitlines()) == set(initial) | {'package:' + PACKAGE}
        before = '\n'.join(initial) + '\n'
        assert hashlib.sha256((output / 'ui-tested-debug.apk').read_bytes()).hexdigest() == result['apk_sha256']
    else:
        assert 'package:' + PACKAGE not in before.splitlines(), 'Never overwrite existing data'
    snapshot = output / 'pr82-evidence/USD-verified.sqlite'
    plain = json.loads((output / 'pr82-evidence/USD-plaintext.json').read_text(encoding='utf-8'))
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    if not args.resume_prepared:
        assert hashlib.sha256(apk.read_bytes()).hexdigest() == result['apk_sha256']
        shutil.copyfile(apk, output / 'ui-tested-debug.apk')
    env = {key: value for key, value in os.environ.items()
        if not (key.startswith('PUJANGGA_') and key.endswith('_E2E'))}
    env['PUJANGGA_SCALED_E2E'] = '1'
    if not args.resume_prepared:
        print('PR82_COLD_BUILD_START', flush=True)
        with (output / 'cold-build.log').open('w', encoding='utf-8') as log:
            subprocess.run([args.flutter, 'build', 'apk', '--debug', '--no-pub', '--target', TARGET,
                '--dart-define=E2E_SOURCE_REVISION=' + revision], env=env, stdout=log,
                stderr=subprocess.STDOUT, check=True)
    sdk_line = next(x for x in (root / 'android/local.properties').read_text().splitlines() if x.startswith('sdk.dir='))
    sdk = Path(sdk_line.split('=', 1)[1].replace('\\\\', '\\').replace('\\:', ':'))
    aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
    manifest = read([str(aapt), 'dump', 'badging', str(apk)], text=True)
    assert "package: name='" + PACKAGE + "'" in manifest
    activity = re.search(r"launchable-activity: name='([^']+)'", manifest)[1]
    if not args.resume_prepared:
        subprocess.run(adb + ['install', str(apk)], check=True, timeout=120)
    subprocess.run(adb + ['shell', 'am', 'force-stop', PACKAGE], check=True, timeout=30)
    subprocess.run(adb + ['shell', 'run-as', PACKAGE, 'mkdir', '-p', 'cache/pr82-cold'], check=True)
    subprocess.run(adb + ['shell', 'run-as', PACKAGE, 'rm', '-f', 'cache/pr82-cold/result.json'], check=True)
    # Text-safe transport avoids Windows adb stdin truncation on binary Ctrl-Z.
    subprocess.run(adb + ['shell', '-T', 'run-as', PACKAGE, 'sh', '-c',
        "'base64 -d > cache/pr82-cold/source.sqlite'"],
        input=base64.b64encode(snapshot.read_bytes()) + b'\n',
        capture_output=True, check=True, timeout=45)
    native = read(adb + ['exec-out', 'run-as', PACKAGE, 'cat', 'cache/pr82-cold/source.sqlite'])
    assert hashlib.sha256(native).digest() == hashlib.sha256(snapshot.read_bytes()).digest()
    boots = []
    for index in range(2):
        subprocess.run(adb + ['shell', 'am', 'force-stop', PACKAGE], check=True, timeout=30)
        check = subprocess.run(adb + ['shell', 'pidof', PACKAGE], capture_output=True, text=True)
        assert not check.stdout.strip(), 'Previous process must actually be gone'
        subprocess.run(adb + ['shell', 'am', 'start', '-W', '-n', PACKAGE + '/' + activity],
            capture_output=True, check=True, timeout=45)
        boot = None
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            probe = subprocess.run(adb + ['exec-out', 'run-as', PACKAGE, 'cat', 'cache/pr82-cold/result.json'],
                capture_output=True, timeout=15)
            try:
                candidate = json.loads(probe.stdout)
                if not boots or candidate['pid'] != boots[-1]['pid']:
                    boot = candidate
                    break
            except (ValueError, KeyError):
                pass
            time.sleep(0.5)
        assert boot and boot['status'] == 'passed', boot
        assert boot['revision'] == revision and boot['package'] == PACKAGE
        boots.append(boot)
        (output / f'cold-boot-{index+1}.json').write_text(json.dumps(boot, indent=2), encoding='utf-8')
        image = read(adb + ['exec-out', 'screencap', '-p'])
        assert image.startswith(b'\x89PNG')
        (output / f'cold-boot-{index+1}.png').write_bytes(image)
        binary = read(adb + ['exec-out', 'run-as', PACKAGE, 'cat', 'cache/pr82-cold/source.sqlite'])
        pulled = output / f'cold-boot-{index+1}.sqlite'
        pulled.write_bytes(binary)
        with sqlite3.connect(pulled.resolve().as_uri() + '?mode=ro', uri=True) as db:
            db.row_factory = sqlite3.Row
            assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
            for table, expected in plain['tables'].items():
                assert table.replace('_', '').isalnum()
                actual = [dict(row) for row in db.execute('SELECT * FROM "' + table + '" ORDER BY id')]
                assert actual == expected, (index, table)
        print('PR82_COLD_PASS: startup ' + str(index + 1) + ' pid=' + str(boot['pid']), flush=True)
    assert boots[0]['pid'] != boots[1]['pid']
    subprocess.run(adb + ['uninstall', PACKAGE], check=True, timeout=45)
    after = read(inventory, text=True)
    assert set(before.splitlines()) == set(after.splitlines())
    summary = {'status': 'passed', 'revision': revision, 'package': PACKAGE, 'boots': boots,
        'distinct_android_processes': True, 'all_rows_unchanged': True,
        'package_removed': True, 'existing_packages_preserved': True,
        'cold_apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
        'verified_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    (output / 'cold-start-verified.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print('PR82_COLD_COMPLETE: real process restart persistence verified', flush=True)


if __name__ == '__main__':
    main()

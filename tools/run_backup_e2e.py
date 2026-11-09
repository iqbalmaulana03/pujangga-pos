"""Run PR60 backup validation in a new package, never uninstall any package."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--output', default='build/backup-e2e')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / args.output
    output.mkdir(parents=True, exist_ok=True)
    adb = ['adb', '-s', args.device]
    package = 'com.pujanggapos.pujangga_pos.pr60e2e'
    target = 'integration_test/backup_snapshot_test.dart'
    test_environment = dict(os.environ, PUJANGGA_BACKUP_E2E='1')

    def packages():
        return subprocess.check_output(adb + ['shell', 'pm', 'list', 'packages',
            'pujangga'], text=True).strip()

    before = packages()
    (output / 'package-inventory.txt').write_text('BEFORE\n' + before + '\n')
    with (output / 'build.log').open('w', encoding='utf-8') as log:
        subprocess.run([args.flutter, 'build', 'apk', '--debug', '--no-pub',
                        '--target', target], cwd=root, stdout=log,
                       stderr=subprocess.STDOUT, check=True, env=test_environment)
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    (output / 'apk.sha256').write_text(hashlib.sha256(apk.read_bytes()).hexdigest())
    # Refuse to launch if the actual built manifest has another application ID.
    sdk_line = next(line for line in (root / 'android/local.properties').read_text().splitlines()
                    if line.startswith('sdk.dir='))
    sdk = Path(sdk_line.split('=', 1)[1].replace('\\\\', '\\').replace('\\:', ':'))
    aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
    manifest = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)], text=True)
    if f"package: name='{package}'" not in manifest:
        raise RuntimeError('Built APK has wrong package identity')
    (output / 'apk-package.txt').write_text(manifest.splitlines()[0])
    process = subprocess.Popen([args.flutter, 'test', target, '-d', args.device,
        '--no-pub', '--no-uninstall', '--reporter', 'expanded'], cwd=root,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding='utf-8', errors='replace', bufsize=1, env=test_environment)
    share_seen = False
    try:
        with (output / 'run.log').open('w', encoding='utf-8') as log:
            for line in process.stdout:
                print(line, end='', flush=True)
                log.write(line)
                log.flush()
                if 'E2E_SCREENSHOT: ' in line:
                    label = line.split('E2E_SCREENSHOT: ', 1)[1].strip()
                    (output / f'{label}.png').write_bytes(subprocess.check_output(
                        adb + ['exec-out', 'screencap', '-p']))
                if 'E2E_SHARE_OPEN' in line:
                    deadline = time.monotonic() + 10
                    while time.monotonic() < deadline:
                        activity = subprocess.check_output(adb + ['shell', 'dumpsys',
                            'activity', 'activities'], text=True)
                        resumed = '\n'.join(row for row in activity.splitlines()
                            if 'mResumedActivity' in row or 'topResumedActivity' in row)
                        if 'ChooserActivity' in resumed:
                            (output / 'share-activity.txt').write_text(resumed)
                            (output / 'native-share.png').write_bytes(subprocess.check_output(
                                adb + ['exec-out', 'screencap', '-p']))
                            subprocess.run(adb + ['shell', 'input', 'keyevent', '4'], check=True)
                            share_seen = True
                            break
                        time.sleep(0.2)
                    if not share_seen:
                        raise RuntimeError('Native share chooser was not observed')
        result = process.wait()
        (output / 'tested-apk.sha256').write_text(hashlib.sha256(apk.read_bytes()).hexdigest())
        if result == 0 and not share_seen:
            raise RuntimeError('Missing native share checkpoint')
        return result
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)
        after = packages()
        with (output / 'package-inventory.txt').open('a') as inventory:
            inventory.write('AFTER\n' + after + '\n')
        if not set(before.splitlines()).issubset(after.splitlines()):
            raise RuntimeError('An existing package disappeared')


if __name__ == '__main__':
    sys.exit(main())

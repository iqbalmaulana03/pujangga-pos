"""Verify the real Android Sharesheet using a dedicated app/database; never send."""
import argparse
import json
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
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / 'build/receipt-share-e2e'
    output.mkdir(parents=True, exist_ok=True)
    adb = ['adb', '-s', args.device]
    package = 'com.pujanggapos.pujangga_pos.issue55e2e'
    target = 'integration_test/receipt_share_test.dart'
    environment = dict(os.environ, PUJANGGA_RECEIPT_E2E='1')

    def adb_text(*command):
        return subprocess.check_output(adb + list(command), text=True, encoding='utf-8', errors='replace')

    def inventory():
        return set(adb_text('shell', 'pm', 'list', 'packages', 'pujangga').splitlines())

    before = inventory()
    with (output / 'build.log').open('w', encoding='utf-8') as log:
        subprocess.run([args.flutter, 'build', 'apk', '--debug', '--no-pub',
                        '--target-platform', 'android-arm64', '--target', target],
                       cwd=root, env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
    sdk_line = next(line for line in (root / 'android/local.properties').read_text().splitlines()
                    if line.startswith('sdk.dir='))
    sdk = Path(sdk_line.split('=', 1)[1].replace('\\\\', '\\').replace('\\:', ':'))
    aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    manifest = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)], text=True)
    if f"package: name='{package}'" not in manifest:
        raise RuntimeError('Wrong package: refusing device execution')
    process = subprocess.Popen([args.flutter, 'test', target, '-d', args.device,
                               '--no-pub', '--no-uninstall', '--reporter', 'expanded'],
                              cwd=root, env=environment, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
    chooser_verified = False
    try:
        with (output / 'run.log').open('w', encoding='utf-8') as log:
            for line in process.stdout:
                print(line, end='', flush=True)
                log.write(line)
                log.flush()
                if 'E2E_SHARE_OPEN' in line:
                    for _ in range(20):
                        activity = adb_text('shell', 'dumpsys', 'activity', 'activities')
                        resumed = [row.strip() for row in activity.splitlines()
                                   if 'mResumedActivity' in row or 'topResumedActivity' in row]
                        if any('ChooserActivity' in row for row in resumed):
                            chooser_verified = True
                            # Persist only activity identity; no contacts or personal share targets.
                            (output / 'chooser-activity.txt').write_text('\n'.join(resumed))
                            print('HOST_NATIVE_CHOOSER_VERIFIED', flush=True)
                            adb_text('shell', 'input', 'keyevent', '4')
                            break
                        time.sleep(1)
                    if not chooser_verified:
                        raise RuntimeError('Android Sharesheet did not become foreground')
        code = process.wait()
        after = inventory()
        result = {'exit_code': code, 'native_chooser_verified': chooser_verified,
                  'existing_packages_preserved': before.issubset(after), 'package': package}
        (output / 'result.json').write_text(json.dumps(result, indent=2))
        if code or not chooser_verified or not before.issubset(after):
            raise RuntimeError('Receipt share E2E failed; inspect bounded build/run logs')
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)


if __name__ == '__main__':
    main()

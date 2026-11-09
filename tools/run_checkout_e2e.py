"""Run the checkout regression on Android, including a native ADB back event.

Requires an authorized, unlocked Android device. Uses the debug package and a
unique disposable SQLite database; never clears app data or touches production.
"""

import argparse
from pathlib import Path
import subprocess
import sys


def main():
    # Flutter prints Unicode status symbols even when Windows defaults to cp1252.
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', default='flutter')
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--output', default='build/checkout-e2e')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = (root / args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    adb = [args.adb, '-s', args.device]
    subprocess.run(adb + ['get-state'], check=True, capture_output=True)
    production = 'com.pujanggapos.pujangga_pos'

    def production_installed():
        packages = subprocess.check_output(
            adb + ['shell', 'pm', 'list', 'packages', production], text=True)
        return f'package:{production}' in packages.splitlines()

    before = production_installed()
    (output / 'package-inventory.txt').write_text(
        f'production_before={before}\n', encoding='utf-8')
    # On a clean checkout Flutter may cache the unsuffixed namespace before
    # building, then uninstall that package after running the debug APK.
    # Build first so package discovery reads the actual debug manifest, and
    # independently disable Flutter's automatic uninstall.
    with (output / 'preflight-build.log').open('w', encoding='utf-8') as log:
        subprocess.run(
            [args.flutter, 'build', 'apk', '--debug', '--no-pub',
             '--target', 'integration_test/checkout_commit_test.dart'],
            cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True)
    command = [args.flutter, 'test', 'integration_test/checkout_commit_test.dart',
               '-d', args.device, '--no-pub', '--no-uninstall',
               '--reporter', 'expanded']
    # Batch entrypoints are launched through cmd by Windows, without shell=True.
    process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True,
                               encoding='utf-8', errors='replace', bufsize=1)
    sent_back = False
    try:
        with (output / 'run.log').open('w', encoding='utf-8') as log:
            for line in process.stdout:
                print(line, end='', flush=True)
                log.write(line)
                log.flush()
                if 'E2E_WAIT_ANDROID_BACK' not in line:
                    continue
                if sent_back:
                    raise RuntimeError('Unexpected second native-back checkpoint')
                foreground = subprocess.check_output(
                    adb + ['shell', 'dumpsys', 'activity', 'activities'], text=True)
                resumed = [row for row in foreground.splitlines()
                           if 'mResumedActivity' in row or 'topResumedActivity' in row]
                if not any('com.pujanggapos.pujangga_pos.debug/' in row
                           for row in resumed):
                    raise RuntimeError('Refusing input: test debug app is not foreground')
                screenshot = subprocess.check_output(adb + ['exec-out', 'screencap', '-p'])
                (output / 'committed-receipt.png').write_bytes(screenshot)
                subprocess.run(adb + ['shell', 'input', 'keyevent', '4'], check=True)
                sent_back = True
        code = process.wait()
        if code == 0 and not sent_back:
            raise RuntimeError('Test did not reach the native-back checkpoint')
        return code
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)
        after = production_installed()
        with (output / 'package-inventory.txt').open('a', encoding='utf-8') as log:
            log.write(f'production_after={after}\n')
        if before and not after:
            raise RuntimeError('Production package disappeared during the run')


if __name__ == '__main__':
    sys.exit(main())

"""Run PR61 on Android in a dedicated package and preserve existing apps."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import sys


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / 'build/dataset-e2e'
    output.mkdir(parents=True, exist_ok=True)
    adb = ['adb', '-s', args.device]
    package = 'com.pujanggapos.pujangga_pos.pr61e2e'
    target = 'integration_test/dataset_replacement_test.dart'
    environment = dict(os.environ, PUJANGGA_DATASET_E2E='1')

    def inventory():
        return subprocess.check_output(adb + ['shell', 'pm', 'list', 'packages',
            'pujangga'], text=True).strip()

    before = inventory()
    (output / 'package-inventory.txt').write_text('BEFORE\n' + before + '\n')
    (output / 'source-revision.txt').write_text(subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=root, text=True))
    with (output / 'build.log').open('w', encoding='utf-8') as log:
        subprocess.run([args.flutter, 'build', 'apk', '--debug', '--no-pub',
            '--target-platform', 'android-arm64',
            '--target', target], cwd=root, env=environment, stdout=log,
            stderr=subprocess.STDOUT, check=True)
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    sdk_line = next(line for line in (root / 'android/local.properties').read_text().splitlines()
                    if line.startswith('sdk.dir='))
    sdk = Path(sdk_line.split('=', 1)[1].replace('\\\\', '\\').replace('\\:', ':'))
    aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
    manifest = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)], text=True)
    if f"package: name='{package}'" not in manifest:
        raise RuntimeError('Wrong package; refusing to install or launch')
    (output / 'apk-package.txt').write_text(manifest.splitlines()[0])
    process = subprocess.Popen([args.flutter, 'test', target, '-d', args.device,
        '--no-pub', '--no-uninstall', '--reporter', 'expanded'], cwd=root,
        env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding='utf-8', errors='replace', bufsize=1)
    try:
        with (output / 'run.log').open('w', encoding='utf-8') as log:
            for line in process.stdout:
                print(line, end='', flush=True)
                log.write(line)
                log.flush()
                if 'E2E_SCREENSHOT: ' in line:
                    label = line.split('E2E_SCREENSHOT: ', 1)[1].strip()
                    if not label.replace('-', '').isalnum():
                        raise RuntimeError('Invalid screenshot label')
                    activity = subprocess.check_output(adb + ['shell', 'dumpsys',
                        'activity', 'activities'], text=True)
                    resumed = [row for row in activity.splitlines()
                        if 'mResumedActivity' in row or 'topResumedActivity' in row]
                    if not any(package + '/' in row for row in resumed):
                        raise RuntimeError('Refusing screenshot outside the test app')
                    (output / f'{label}.png').write_bytes(subprocess.check_output(
                        adb + ['exec-out', 'screencap', '-p']))
        code = process.wait()
        (output / 'tested-apk.sha256').write_text(hashlib.sha256(apk.read_bytes()).hexdigest())
        return code
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)
        after = inventory()
        with (output / 'package-inventory.txt').open('a') as log:
            log.write('AFTER\n' + after + '\n')
        if not set(before.splitlines()).issubset(after.splitlines()):
            raise RuntimeError('An existing package disappeared')


if __name__ == '__main__':
    sys.exit(main())

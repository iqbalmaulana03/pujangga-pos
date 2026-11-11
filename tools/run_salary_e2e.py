"""Run salary reconciliation E2E on Android without touching existing POS apps."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / 'build/pr66-e2e'
    output.mkdir(parents=True, exist_ok=True)
    package = 'com.pujanggapos.pujangga_pos.pr66e2e'
    target = 'integration_test/salary_reconciliation_test.dart'
    environment = dict(os.environ, PUJANGGA_SALARY_E2E='1')

    def adb(*arguments, check=True):
        return subprocess.run(['adb', '-s', args.device, *arguments],
                              capture_output=True, check=check, timeout=30)

    if adb('get-state').stdout.strip() != b'device':
        raise RuntimeError('Device is not ready')
    if adb('shell', 'pm', 'path', package, check=False).stdout.strip():
        raise RuntimeError('Test package already exists; refusing to overwrite it')
    protected = ['com.pujanggapos.pujangga_pos', 'com.pujanggapos.pujangga_pos.debug']
    before = {p: adb('shell', 'pm', 'path', p, check=False).stdout for p in protected}
    result = {
        'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'package': package,
        'android': adb('shell', 'getprop', 'ro.build.version.release').stdout.decode().strip(),
        'model': adb('shell', 'getprop', 'ro.product.model').stdout.decode().strip(),
        'events': [],
    }
    print('E2E_BUILD: dedicated package, existing apps preserved', flush=True)
    with (output / 'build.log').open('w', encoding='utf-8') as log:
        subprocess.run([args.flutter, 'build', 'apk', '--debug', '--no-pub',
                        '--target-platform', 'android-arm64', '--target', target],
                       cwd=root, env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    properties = (root / 'android/local.properties').read_text()
    sdk = next(line.split('=', 1)[1] for line in properties.splitlines() if line.startswith('sdk.dir='))
    sdk = Path(sdk.replace('\\\\', '\\').replace('\\:', ':'))
    aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
    manifest = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)], text=True)
    if f"package: name='{package}'" not in manifest:
        raise RuntimeError('Wrong APK identity; refusing installation')
    result['apk_identity'] = manifest.splitlines()[0]
    process = None
    try:
        process = subprocess.Popen([args.flutter, 'test', target, '-d', args.device,
            '--no-pub', '--no-uninstall', '--reporter', 'expanded'], cwd=root,
            env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding='utf-8', errors='replace', bufsize=1)
        with (output / 'run.log').open('w', encoding='utf-8') as log:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if 'E2E_' in line or 'passed!' in line or '[E]' in line:
                    print(line, end='', flush=True)
                if 'E2E_PASS:' in line or 'E2E_CLEANUP:' in line:
                    result['events'].append(line.strip())
                if 'E2E_SCREENSHOT: ' in line:
                    label = line.split('E2E_SCREENSHOT: ', 1)[1].strip()
                    if not re.fullmatch(r'[a-zA-Z0-9-]+', label):
                        raise RuntimeError('Invalid screenshot label')
                    activities = adb('shell', 'dumpsys', 'activity', 'activities').stdout.decode()
                    resumed = [s for s in activities.splitlines() if 'mResumedActivity' in s or 'topResumedActivity' in s]
                    if not any(package + '/' in s for s in resumed):
                        raise RuntimeError('Refusing screenshot outside the test app')
                    (output / f'{label}.png').write_bytes(adb('exec-out', 'screencap', '-p').stdout)
        result['exit_code'] = process.wait()
        result['apk_sha256'] = hashlib.sha256(apk.read_bytes()).hexdigest()
        return result['exit_code']
    finally:
        if process and process.poll() is None:
            process.terminate()
            process.wait(timeout=15)
        # Package was absent before this run; only this exact test package is owned.
        if adb('shell', 'pm', 'path', package, check=False).stdout.strip():
            adb('uninstall', package)
        result['test_package_removed'] = not adb('shell', 'pm', 'path', package, check=False).stdout.strip()
        result['protected_package_paths_unchanged'] = all(
            adb('shell', 'pm', 'path', p, check=False).stdout == before[p] for p in protected)
        (output / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        if not result['test_package_removed'] or not result['protected_package_paths_unchanged']:
            raise RuntimeError('Post-run package inventory mismatch')


if __name__ == '__main__':
    sys.exit(main())

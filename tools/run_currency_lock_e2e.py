"""Test PR83 on Android with an isolated package/database and native share cancel."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--output', default='build/currency-lock-e2e')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = (root / args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    package = 'com.pujanggapos.pujangga_pos.pr83e2e'
    target = 'integration_test/currency_lock_test.dart'
    environment = {k: v for k, v in os.environ.items()
                   if not (k.startswith('PUJANGGA_') and k.endswith('_E2E'))}
    environment['PUJANGGA_CURRENCY_LOCK_E2E'] = '1'
    adb = ['adb', '-s', args.device]

    def command_text(command):
        return subprocess.check_output(command, cwd=root, env=environment,
            text=True, encoding='utf-8', errors='replace', timeout=60).strip()

    def adb_text(*command):
        return command_text(adb + list(command))

    def inventory():
        return set(adb_text('shell', 'pm', 'list', 'packages', 'pujangga').splitlines())

    def foreground():
        return [line.strip() for line in adb_text('shell', 'dumpsys', 'activity',
            'activities').splitlines() if 'mResumedActivity' in line or 'topResumedActivity' in line]

    if adb_text('get-state') != 'device':
        raise RuntimeError('ADB device not ready')
    before = inventory()
    # A unique package avoids replacing existing applications or their data.
    if f'package:{package}' in before:
        print('Reusing dedicated PR83 test package; per-case databases remain unique.', flush=True)
    revision = command_text(['git', 'rev-parse', 'HEAD'])
    (output / 'source-revision.txt').write_text(revision + '\n', encoding='utf-8')
    (output / 'source-diff.patch').write_text(command_text(['git', 'diff']), encoding='utf-8')
    (output / 'device.json').write_text(json.dumps({
        'model': adb_text('shell', 'getprop', 'ro.product.model'),
        'android': adb_text('shell', 'getprop', 'ro.build.version.release'),
        'sdk': adb_text('shell', 'getprop', 'ro.build.version.sdk'),
        'package': package,
    }, indent=2), encoding='utf-8')
    (output / 'sdk.txt').write_text(command_text([args.flutter, '--version']), encoding='utf-8')
    print('Building isolated PR83 Android APK...', flush=True)
    with (output / 'build.log').open('w', encoding='utf-8') as log:
        subprocess.run([args.flutter, 'build', 'apk', '--debug', '--no-pub',
            '--target-platform', 'android-arm64', '--target', target], cwd=root,
            env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    sdk_line = next(line for line in (root / 'android/local.properties').read_text().splitlines()
                    if line.startswith('sdk.dir='))
    sdk = Path(sdk_line.split('=', 1)[1].replace('\\\\', '\\').replace('\\:', ':'))
    aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
    manifest = command_text([str(aapt), 'dump', 'badging', str(apk)])
    if f"package: name='{package}'" not in manifest:
        raise RuntimeError('Wrong application ID; refusing install')
    (output / 'apk-package.txt').write_text(manifest.splitlines()[0], encoding='utf-8')
    process = subprocess.Popen([args.flutter, 'test', target, '-d', args.device,
        '--no-pub', '--no-uninstall', '--reporter', 'expanded'], cwd=root,
        env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding='utf-8', errors='replace', bufsize=1)
    chooser_verified = False
    passes = []
    screenshots = []
    try:
        with (output / 'run.log').open('w', encoding='utf-8') as log:
            for line in process.stdout:
                log.write(line)
                log.flush()
                if any(marker in line for marker in ['E2E_', 'All tests passed', '[E]', 'EXCEPTION', 'Expected:', 'Actual:', 'Error:', 'failed']):
                    print(line, end='', flush=True)
                if 'E2E_PASS: ' in line:
                    passes.append(line.split('E2E_PASS: ', 1)[1].strip())
                if 'E2E_SCREENSHOT: ' in line:
                    label = line.split('E2E_SCREENSHOT: ', 1)[1].strip()
                    if not re.fullmatch(r'[a-zA-Z0-9-]+', label):
                        raise RuntimeError('Invalid screenshot label')
                    if not any(package + '/' in row for row in foreground()):
                        raise RuntimeError('Refusing screenshot outside synthetic test app')
                    (output / f'{label}.png').write_bytes(subprocess.check_output(adb + ['exec-out', 'screencap', '-p'], timeout=30))
                    screenshots.append(label)
                if 'E2E_SHARE_OPEN' in line:
                    for _ in range(20):
                        resumed = foreground()
                        if any('ChooserActivity' in row for row in resumed):
                            chooser_verified = True
                            # Store only component identity; never capture personal share targets.
                            (output / 'chooser-activity.txt').write_text('\n'.join(resumed), encoding='utf-8')
                            adb_text('shell', 'input', 'keyevent', '4')
                            print('HOST_NATIVE_CHOOSER_VERIFIED_AND_CANCELLED', flush=True)
                            break
                        time.sleep(0.5)
                    if not chooser_verified:
                        raise RuntimeError('Native Android Sharesheet not observed')
        code = process.wait()
        after = inventory()
        result = {'exit_code': code, 'source_revision': revision,
            'package': package, 'native_chooser_verified': chooser_verified,
            'existing_packages_preserved': before.issubset(after),
            'packages_before': sorted(before), 'packages_after': sorted(after),
            'passes': passes, 'screenshots': screenshots,
            'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest()}
        (output / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        if code or len(passes) != 7 or not chooser_verified or not before.issubset(after):
            raise RuntimeError('PR83 E2E failed; inspect run.log and result.json')
        print('PR83_E2E_PASS: 7 scenarios, native chooser, package preservation verified', flush=True)
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=30)


if __name__ == '__main__':
    main()

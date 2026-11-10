"""Run isolated Android restore tests, including the native file picker."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='adb device serial')
    parser.add_argument('--suite', choices=['validation', 'limits'], default='validation')
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    parser.add_argument('--adb', default=shutil.which('adb'))
    parser.add_argument('--aapt2', default=shutil.which('aapt2'))
    args = parser.parse_args()
    if not args.flutter or not args.adb:
        parser.error('Flutter and adb must be available or specified explicitly')
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    root = Path(__file__).resolve().parents[1]
    limits = args.suite == 'limits'
    tag = 'PR64' if limits else 'PR62'
    target = 'integration_test/restore_limits_test.dart' if limits else 'integration_test/restore_validation_test.dart'
    fixture_names = {'limit-bytes.json', 'valid-large.json'} if limits else {'invalid-date.json', 'valid-schema-16.json'}
    artifacts = root / 'build' / f'{tag.lower()}-e2e'
    artifacts.mkdir(parents=True, exist_ok=True)
    package = f'com.pujanggapos.pujangga_pos.{tag.lower()}e2e'
    folder = f'000-{tag}-E2E-{time.time_ns()}'
    shared = f'/sdcard/{folder}'
    ui_dump = f'/data/local/tmp/{folder}.xml'
    copied = []
    native_selections = 0
    native_errors = []
    memory_samples = []
    sample_stop = threading.Event()
    sampler = None
    process = None

    def adb(*arguments, check=True, timeout=15):
        return subprocess.run([args.adb, '-s', args.device, *arguments],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              check=check, timeout=timeout)

    def tap(node):
        numbers = list(map(int, re.findall(r'\d+', node.attrib['bounds'])))
        left, top, right, bottom = numbers
        adb('shell', 'input', 'tap', str((left + right) // 2), str((top + bottom) // 2))

    def sample_memory():
        # Record only aggregate test-process memory, never app rows or user data.
        while not sample_stop.is_set():
            try:
                output = adb('shell', 'dumpsys', 'meminfo', package).stdout.decode(errors='replace')
                pss = re.search(r'TOTAL PSS:\s+(\d+)', output)
                rss = re.search(r'TOTAL RSS:\s+(\d+)', output)
                if pss:
                    memory_samples.append({'monotonic': round(time.monotonic(), 3),
                        'pss_kib': int(pss.group(1)),
                        'rss_kib': int(rss.group(1)) if rss else None})
            except (subprocess.SubprocessError, OSError):
                pass
            sample_stop.wait(0.25)

    storage_names = {'internal storage', 'penyimpanan internal'}
    for prop in ['ro.product.model', 'ro.product.marketname']:
        value = adb('shell', 'getprop', prop).stdout.decode().strip().lower()
        if value:
            storage_names.add(value)

    aapt2 = args.aapt2
    if not aapt2:
        sdk = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
        if not sdk:
            properties = (root / 'android' / 'local.properties').read_text(encoding='utf-8')
            sdk = next((line.split('=', 1)[1].strip().replace('\\\\', '\\').replace('\\:', ':')
                        for line in properties.splitlines() if line.startswith('sdk.dir=')), None)
        candidates = sorted((Path(sdk) / 'build-tools').glob('*/aapt2*')) if sdk else []
        if not candidates:
            parser.error('Specify --aapt2 from the Android SDK build-tools')
        aapt2 = str(candidates[-1])

    def choose_native_file(source):
        # Export only this test's private synthetic fixture. Never enumerate or
        # read another app's data, or log the names of other DocumentsUI files.
        prefix = f'/data/user/0/{package}/cache/restore-'
        if not source.startswith(prefix) or Path(source).name not in fixture_names:
            raise RuntimeError('Unexpected fixture path; refusing to copy')
        content = adb('exec-out', 'run-as', package, 'cat', source).stdout
        json.loads(content)
        local = artifacts / Path(source).name
        local.write_bytes(content)
        remote_name = f'{folder}-{local.name}'
        remote = f'{shared}/{remote_name}'
        adb('push', str(local), remote)
        copied.append(remote)
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            adb('shell', 'uiautomator', 'dump', '--compressed', ui_dump)
            raw = adb('exec-out', 'cat', ui_dump).stdout
            document = ET.fromstring(raw[raw.index(b'<?xml'):])
            nodes = list(document.iter('node'))
            # These exact labels belong only to the files/folder we just made.
            file_node = next((n for n in nodes if n.get('text') == remote_name), None)
            if file_node is not None:
                tap(file_node)
                print(f'E2E_NATIVE_SELECTED: {local.name}', flush=True)
                return
            folder_node = next((n for n in nodes if n.get('text') == folder), None)
            if folder_node is not None:
                tap(folder_node)
                time.sleep(0.3)
                continue
            # Select Downloads only in the roots drawer, never a toolbar title.
            roots = next((n for n in nodes if 'roots_list' in n.get('resource-id', '')), None)
            root_labels = {'recent', 'images', 'videos', 'audio', 'documents',
                           'terbaru', 'gambar', 'video', 'dokumen'}
            drawer_visible = roots is not None or sum(
                n.get('text', '').lower() in root_labels for n in nodes) >= 2
            if drawer_visible:
                # The Downloads provider can omit files pushed by adb. Browse
                # the device's primary storage root, whose label is Build.MODEL
                # or the vendor market name, then its actual Download folder.
                storage = next((n for n in nodes if n.get('text', '').lower() in storage_names), None)
                if storage is not None:
                    print('E2E_NATIVE_NAV: primary storage root', flush=True)
                    tap(storage)
                    time.sleep(0.3)
                    continue
                download = next((n for n in (roots.iter('node') if roots is not None else nodes)
                                 if n.get('text', '').lower() in {'downloads', 'download', 'unduhan'}), None)
                if download is not None:
                    print('E2E_NATIVE_NAV: Downloads root', flush=True)
                    tap(download)
                    time.sleep(0.3)
                    continue
            download_folder = next((n for n in nodes if n.get('text') == 'Download'), None)
            if not drawer_visible and download_folder is not None:
                print('E2E_NATIVE_NAV: Download folder', flush=True)
                tap(download_folder)
                time.sleep(0.3)
                continue
            menu = next((n for n in nodes if n.get('content-desc', '').lower() in {
                'show roots', 'open navigation drawer', 'tampilkan root',
                'tampilkan akar', 'buka panel navigasi'
            } or n.get('resource-id', '').endswith('/roots_button')), None)
            if menu is not None:
                print('E2E_NATIVE_NAV: open roots drawer', flush=True)
                tap(menu)
            time.sleep(0.5)
        # Diagnostic metadata excludes unrelated filenames and all user text.
        metadata = {
            'packages': sorted({n.get('package', '') for n in nodes}),
            'resource_ids': sorted({n.get('resource-id', '') for n in nodes}),
            'system_labels': sorted({n.get('text', '') for n in nodes
                                     if n.get('text', '').lower() in root_labels | {'downloads', 'download', 'unduhan'}}),
        }
        print('E2E_NATIVE_DIAGNOSTIC: ' + json.dumps(metadata), flush=True)
        raise RuntimeError('Native file selection did not finish within 45 seconds')

    if adb('get-state').stdout.strip() != b'device':
        raise RuntimeError('Requested adb device is not ready')
    if adb('shell', 'pm', 'path', package, check=False).stdout.strip():
        raise RuntimeError('Test package already exists; refusing to overwrite or clean another run')
    if adb('shell', 'test', '-e', shared, check=False).returncode != 1:
        raise RuntimeError('Cannot establish ownership of disposable shared folder')
    adb('shell', 'mkdir', shared)
    main_package = 'com.pujanggapos.pujangga_pos'
    main_paths_before = adb('shell', 'pm', 'path', main_package, check=False).stdout
    debug_package = main_package + '.debug'
    debug_paths_before = adb('shell', 'pm', 'path', debug_package, check=False).stdout
    result = 1
    try:
        env = os.environ.copy()
        env['PUJANGGA_RESTORE_LIMITS_E2E' if limits else 'PUJANGGA_RESTORE_E2E'] = '1'
        define = f'--dart-define={tag}_NATIVE_PICKER=true'
        command = [args.flutter, 'test', '--no-pub', '--no-uninstall',
                   target, '-d', args.device, define, '--reporter', 'expanded']
        print(f'E2E_RUN: isolated package {package}; native picker enabled', flush=True)
        with (artifacts / 'android-e2e.log').open('w', encoding='utf-8') as log:
            # Flutter resolves its teardown package before the test build. On a
            # clean checkout it can fall back to the main namespace. Prebuild
            # and verify the actual ID, and disable Flutter's automatic uninstall.
            prebuild = [args.flutter, 'build', 'apk', '--debug', '--no-pub',
                        f'--target={target}',
                        '--target-platform=android-arm64', define]
            builder = subprocess.Popen(prebuild, cwd=root, env=env,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, encoding='utf-8', errors='replace')
            for line in builder.stdout:
                log.write(line)
                log.flush()
                print(line.rstrip(), flush=True)
            if builder.wait() != 0:
                raise RuntimeError('Preflight APK build failed; no test installation attempted')
            apk = root / 'build' / 'app' / 'outputs' / 'flutter-apk' / 'app-debug.apk'
            actual_id = subprocess.check_output([aapt2, 'dump', 'packagename', str(apk)], text=True).strip()
            if actual_id != package:
                raise RuntimeError('Preflight APK package mismatch; refusing to install')
            print(f'E2E_PREFLIGHT: verified APK ID={actual_id}; automatic uninstall disabled', flush=True)
            sampler = threading.Thread(target=sample_memory, daemon=True)
            sampler.start()
            process = subprocess.Popen(command, cwd=root, env=env,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, encoding='utf-8', errors='replace')
            for line in process.stdout:
                log.write(line)
                log.flush()
                print(line.rstrip(), flush=True)
                marker = re.search(r'E2E_SCREENSHOT: ([a-z0-9-]+)', line)
                if marker:
                    activity = adb('shell', 'dumpsys', 'activity', 'activities').stdout.decode(errors='replace')
                    resumed = [row for row in activity.splitlines()
                               if 'mResumedActivity' in row or 'topResumedActivity' in row]
                    if not any(package + '/' in row for row in resumed):
                        raise RuntimeError('Refusing screenshot outside the test package')
                    image = adb('exec-out', 'screencap', '-p').stdout
                    if not image.startswith(b'\x89PNG\r\n\x1a\n'):
                        raise RuntimeError('Invalid screenshot response')
                    target = artifacts / f'{marker.group(1)}.png'
                    target.write_bytes(image)
                    print(f'E2E_CAPTURE: {target.name}, bytes={len(image)}', flush=True)
                native = re.search(r'E2E_NATIVE_PICKER: (\S+)', line)
                if native:
                    try:
                        choose_native_file(native.group(1))
                        native_selections += 1
                    except Exception as error:
                        native_errors.append(type(error).__name__)
                        print(f'E2E_NATIVE_FAILURE: {error}', flush=True)
                        # Cancel our own picker so the test reports failure and
                        # executes its database cleanup rather than hanging.
                        adb('shell', 'input', 'keyevent', '4', '4', '4', check=False)
            result = process.wait()
        if native_selections != 2 or native_errors:
            result = 1
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=15)
        sample_stop.set()
        if sampler:
            sampler.join(timeout=20)
        (artifacts / 'memory.json').write_text(json.dumps(memory_samples, indent=2) + '\n', encoding='utf-8')
        # Each removed path was created by this invocation; no recursive delete
        # or cleanup of the user's shared storage or application packages is used.
        for remote in copied:
            adb('shell', 'rm', remote, check=False)
        adb('shell', 'rm', '-f', ui_dump, check=False)
        adb('shell', 'rmdir', shared, check=False)
        shared_removed = adb('shell', 'test', '-e', shared, check=False).returncode == 1
        # Explicit cleanup is restricted to the APK ID verified above. Never
        # delegate target selection to Flutter's pre-build project namespace.
        if adb('shell', 'pm', 'path', package, check=False).stdout.strip():
            adb('uninstall', package)
        test_removed = not adb('shell', 'pm', 'path', package, check=False).stdout.strip()
        main_unchanged = adb('shell', 'pm', 'path', main_package, check=False).stdout == main_paths_before
        debug_unchanged = adb('shell', 'pm', 'path', debug_package, check=False).stdout == debug_paths_before
        if not (shared_removed and test_removed and main_unchanged and debug_unchanged):
            result = 1
        apk = root / 'build' / 'app' / 'outputs' / 'flutter-apk' / 'app-debug.apk'
        summary = {
            'exit_code': result,
            'native_file_selections': native_selections,
            'native_errors': native_errors,
            'test_package': package,
            'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest() if apk.exists() else None,
            'scenario': target,
            'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
            'memory_samples': len(memory_samples),
            'peak_pss_kib': max((s['pss_kib'] for s in memory_samples), default=None),
            'automatic_uninstall': False,
            'main_package_unchanged': main_unchanged,
            'debug_package_unchanged': debug_unchanged,
            'test_package_removed': test_removed,
            'shared_folder_removed': shared_removed,
        }
        (artifacts / 'result.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
        checks = f'E2E_PACKAGE_CHECK: main_unchanged={main_unchanged}, test_removed={test_removed}, shared_removed={shared_removed}'
        print(checks, flush=True)
        with (artifacts / 'android-e2e.log').open('a', encoding='utf-8') as log:
            log.write(checks + '\n')
        print('E2E_HOST_CLEANUP: completed; see result.json for verification', flush=True)
    print(f'E2E_EXIT: {result}', flush=True)
    return result


if __name__ == '__main__':
    sys.exit(main())

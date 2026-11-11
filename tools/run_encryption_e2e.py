"""PR65 Android E2E with an isolated package and independent crypto transport."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

PACKAGE = 'com.pujanggapos.pujangga_pos.pr65e2e'
PASSWORD = b'PR65 synthetic password'  # Synthetic fixture only.
AAD = b'pujangga_pos_encrypted_backup:1:AES-256-GCM:PBKDF2-HMAC-SHA256:600000'


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--output', default='build/encryption-e2e')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / args.output
    output.mkdir(parents=True, exist_ok=True)
    adb = ['adb', '-s', args.device]
    target = 'integration_test/encrypted_backup_test.dart'
    environment = dict(os.environ, PUJANGGA_ENCRYPTION_E2E='1')
    owned_name = f'pr65-e2e-{uuid.uuid4().hex}.json'
    download = '/sdcard/Download/' + owned_name
    window = '/data/local/tmp/' + owned_name + '.xml'
    share_count = 0
    native_picker = False
    transferred = False
    process = None
    isolation = None

    def run(*command, binary=False):
        return subprocess.check_output(adb + list(command), text=not binary,
                                       timeout=30, stderr=subprocess.PIPE)

    def inventory():
        packages = run('shell', 'pm', 'list', 'packages', 'pujangga').strip()
        metadata = run('shell', 'dumpsys', 'package',
                       'com.pujanggapos.pujangga_pos')
        metadata = '\n'.join(row.strip() for row in metadata.splitlines()
                             if re.match(r'\s*(versionCode=|versionName=|firstInstallTime=|lastUpdateTime=)', row))
        return {'packages': packages.splitlines(), 'main_app_metadata': metadata}

    def screenshot(label):
        (output / f'{label}.png').write_bytes(run('exec-out', 'screencap', '-p', binary=True))

    def nodes():
        # DocumentsUI can return a null accessibility root during its launch.
        # Retry that transient state rather than terminating a live Android test.
        try:
            result = run('shell', 'uiautomator', 'dump', '--compressed', window)
            if 'dumped to:' not in result:
                time.sleep(0.5)
                return []
            return list(ET.fromstring(run('shell', 'cat', window)).iter('node'))
        except (subprocess.CalledProcessError, ET.ParseError):
            time.sleep(0.5)
            return []

    def tap(node):
        x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.attrib['bounds']))
        run('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))
        time.sleep(0.5)

    def native_pick():
        nonlocal native_picker
        deadline = time.monotonic() + 60
        searched = False
        downloads_open = False
        while time.monotonic() < deadline:
            current = nodes()
            # The only file selection allowed is this run's owned fixture.
            matching = [n for n in current if n.attrib.get('text') == owned_name]
            if matching:
                screenshot('native-document-picker')
                tap(matching[0])
                native_picker = True
                (output / 'native-picker.txt').write_text('DocumentsUI selected the run-owned encrypted fixture.\n')
                return
            search = [n for n in current if n.attrib.get('resource-id', '').endswith('/option_menu_search')]
            if search and not searched and downloads_open:
                tap(search[0])
                run('shell', 'input', 'text', owned_name)
                run('shell', 'input', 'keyevent', '66')
                searched = True
            else:
                # DocumentsUI roots drawer -> Downloads if current view is empty.
                roots = [n for n in current if n.attrib.get('content-desc') in
                         ('Show roots', 'Tampilkan akar', 'Tampilkan root', 'Buka navigasi', 'Open navigation drawer')]
                downloads = [n for n in current if n.attrib.get('text') in ('Downloads', 'Unduhan', 'Download')]
                if downloads:
                    tap(downloads[0])
                    downloads_open = True
                    searched = False
                elif roots:
                    tap(roots[0])
                else:
                    time.sleep(0.5)
        screenshot('native-picker-timeout')
        raise RuntimeError('Could not select the owned file in native DocumentsUI')

    def transport(file_path):
        nonlocal transferred
        prefix = f'/data/user/0/{PACKAGE}/cache/encryption-e2e-'
        if not file_path.startswith(prefix) or '/..' in file_path:
            raise RuntimeError('Export path is not in the isolated test cache')
        raw = run('exec-out', 'run-as', PACKAGE, 'cat', file_path, binary=True)
        envelope = json.loads(raw)
        unb64 = lambda name: base64.b64decode(envelope[name], validate=True)
        def derive(salt):
            return PBKDF2HMAC(algorithm=hashes.SHA256(), length=32,
                             salt=salt, iterations=600000).derive(PASSWORD)
        plaintext = AESGCM(derive(unb64('salt'))).decrypt(
            unb64('nonce'), unb64('ciphertext') + unb64('tag'), AAD)
        payload = json.loads(plaintext)
        assert payload['tables']['employees'][0]['monthly_salary'] == 7654321
        assert len(payload['tables']['sales_transactions']) == 1
        salt, nonce = os.urandom(16), os.urandom(12)
        encrypted = AESGCM(derive(salt)).encrypt(nonce, plaintext, AAD)
        b64 = lambda value: base64.b64encode(value).decode('ascii')
        envelope.update(salt=b64(salt), nonce=b64(nonce),
                        ciphertext=b64(encrypted[:-16]), tag=b64(encrypted[-16:]))
        fixture = output / 'independent-host-backup.json'
        fixture.write_text(json.dumps(envelope), encoding='utf-8')
        # Refuse to overwrite an existing shared-storage file.
        exists = subprocess.run(adb + ['shell', 'test', '-e', download], capture_output=True).returncode
        if exists == 0:
            raise RuntimeError('Owned download unexpectedly already exists')
        subprocess.run(adb + ['push', str(fixture), download], check=True, capture_output=True)
        transferred = True
        run('shell', 'am', 'broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
            '-d', 'file://' + download)
        parent = file_path.rsplit('/', 1)[0]
        run('shell', 'run-as', PACKAGE, 'touch', parent + '/host-ready')
        (output / 'crypto-transport.txt').write_text(
            'PASS: Android export authenticated/decrypted using Python cryptography.\n'
            'PASS: Synthetic salary and sale verified; fresh salt/nonce generated by Python.\n'
            f'Envelope SHA256: {hashlib.sha256(raw).hexdigest()}\n'
            f'Independent envelope SHA256: {hashlib.sha256(fixture.read_bytes()).hexdigest()}\n')

    before = inventory()
    (output / 'inventory-before.json').write_text(json.dumps(before, indent=2))
    (output / 'source-revision.txt').write_text(subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip())
    try:
        with (output / 'build.log').open('w', encoding='utf-8') as log:
            subprocess.run([args.flutter, 'build', 'apk', '--debug', '--no-pub',
                            '--target', target], cwd=root, stdout=log,
                           stderr=subprocess.STDOUT, check=True, env=environment)
        apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
        sdk_line = next(line for line in (root / 'android/local.properties').read_text().splitlines()
                        if line.startswith('sdk.dir='))
        sdk = Path(sdk_line.split('=', 1)[1].replace('\\\\', '\\').replace('\\:', ':'))
        aapt = sorted((sdk / 'build-tools').glob('*/aapt.exe'))[-1]
        manifest = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)], text=True)
        if f"package: name='{PACKAGE}'" not in manifest:
            raise RuntimeError('Built APK has wrong application ID; refusing device test')
        (output / 'apk-package.txt').write_text(manifest.splitlines()[0])
        process = subprocess.Popen([args.flutter, 'test', target, '-d', args.device,
            '--no-pub', '--no-uninstall', '--reporter', 'expanded'], cwd=root,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            encoding='utf-8', errors='replace', bufsize=1, env=environment)
        with (output / 'run.log').open('w', encoding='utf-8') as log:
            for line in process.stdout:
                print(line, end='', flush=True)
                log.write(line)
                log.flush()
                if 'E2E_SCREENSHOT: ' in line:
                    screenshot(line.split('E2E_SCREENSHOT: ', 1)[1].strip())
                if 'E2E_ISOLATION: ' in line:
                    isolation = line.split('E2E_ISOLATION: ', 1)[1].strip()
                    if not re.fullmatch(r'/data/user/0/' + re.escape(PACKAGE) + r'/cache/encryption-e2e-\d+', isolation):
                        raise RuntimeError('Invalid isolation directory')
                if 'E2E_EXPORT: ' in line:
                    transport(line.split('E2E_EXPORT: ', 1)[1].strip())
                if 'E2E_PICK_NATIVE' in line:
                    native_pick()
                if 'E2E_SHARE_OPEN: ' in line:
                    deadline = time.monotonic() + 10
                    observed = False
                    while time.monotonic() < deadline:
                        activity = run('shell', 'dumpsys', 'activity', 'activities')
                        resumed = '\n'.join(row for row in activity.splitlines()
                            if 'mResumedActivity' in row or 'topResumedActivity' in row)
                        if 'ChooserActivity' in resumed:
                            share_count += 1
                            (output / f'share-{share_count}.txt').write_text(resumed)
                            screenshot(f'native-share-{share_count}')
                            run('shell', 'input', 'keyevent', '4')
                            observed = True
                            break
                        time.sleep(0.2)
                    if not observed:
                        raise RuntimeError('Native share chooser was not observed')
        result = process.wait()
        (output / 'tested-apk.sha256').write_text(hashlib.sha256(apk.read_bytes()).hexdigest())
        if result == 0 and (share_count != 2 or not native_picker or not transferred):
            raise RuntimeError('Missing native/crypto checkpoints')
        (output / 'result.txt').write_text(f'exit_code={result}\nshares={share_count}\nnative_picker={native_picker}\n')
        return result
    finally:
        if process is not None and process.poll() is None:
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True)
            process.wait(timeout=15)
            run('shell', 'am', 'force-stop', PACKAGE)
            # The app cannot run Dart teardown after an infrastructure failure.
            # Inventory and remove only the validated directory from this run.
            if isolation is not None:
                listing = run('shell', 'run-as', PACKAGE, 'ls', isolation)
                (output / 'interrupted-test-files.txt').write_text(listing)
                run('shell', 'run-as', PACKAGE, 'rm', '-r', isolation)
        # Only exact paths created by this run, no clear-data or uninstall.
        if transferred:
            run('shell', 'rm', download)
            assert subprocess.run(adb + ['shell', 'test', '-e', download], capture_output=True).returncode != 0
        subprocess.run(adb + ['shell', 'rm', '-f', window], capture_output=True)
        after = inventory()
        (output / 'inventory-after.json').write_text(json.dumps(after, indent=2))
        assert set(before['packages']).issubset(after['packages'])
        assert before['main_app_metadata'] == after['main_app_metadata'], 'Main application metadata changed'


if __name__ == '__main__':
    sys.exit(main())

"""Audit current Handy Bookmark/workspace evidence; never infer device certification."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
evidence = root / 'docs/qa/evidence'
apps = {'tools', 'docs', 'media', 'dev', 'keep', 'recall', 'bookmark'}
errors = []

def read(name):
    return json.loads((evidence / name).read_text(encoding='utf-8-sig'))

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def require(condition, message):
    if not condition:
        errors.append(message)

source = subprocess.check_output([sys.executable, str(root / 'tooling/flutter-source-fingerprint.py')], text=True).strip()
raw = (evidence / 'flutter-analyze.log').read_bytes()
analysis = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
require('SUCCESS' in analysis[-250:] and 'FAILED' not in analysis, 'Workspace analyze did not finish successfully')
subprocess.run([sys.executable, str(root / 'tooling/flutter-test-summary.py')], check=True)
tests = read('flutter-tests-summary.json')
require(tests['melosSuccess'] and tests['logSha256'] == digest(evidence / 'flutter-tests.log'), 'Workspace test log/summary mismatch')
require({row['package'] for row in tests['packages']} >= {'handy_bookmark', 'handy_bookmark_engine'}, 'Save tests absent')
build_count = 0
for target in ['apk', 'windows', 'web']:
    rows = read(f'builds-{target}.json')
    require(len(rows) == 7 and {row['app'] for row in rows} == apps, f'{target}: seven unique app records required')
    for row in rows:
        valid = row['exitCode'] == 0 and row['sourceUnchanged'] and row['sourceSha256'] == source
        require(valid, f"{row['app']}/{target}: unsuccessful or stale build")
        build_count += int(valid)
        if target == 'apk':
            path = root / row.get('artifact', '')
            require(path.is_file() and digest(path) == row.get('artifactSha256'), f"{row['app']}: main APK missing/hash mismatch")
msix_count = 0
for app in sorted(apps):
    row = read(f'{app}-msix-result.json')
    path = Path(row['artifact'])
    valid = (row['sourceSha256'] == source and row['makeAppxValidated'] and
             not row['signed'] and not row['installed'] and not row['storeApproved'] and
             path.is_file() and digest(path) == row['sha256'])
    require(valid, f'{app}: unsigned MSIX missing/hash/source mismatch')
    msix_count += int(valid)
native = read('save-android-screenshots-result.json')
require(native['exitCode'] == 0 and native['sourceUnchanged'] and native['sourceSha256'] == source and not native['physicalDevice'], 'Save Android emulator integration stale/failed')
share = read('save-native-share-result.json')
require(share['passed'] and share['sourceSha256'] == source and share['coldAndWarm'] and share['multipleUrls'] and share['ackQueueEmpty'] and not share['physicalDevice'], 'Save real cold/warm share smoke stale/failed')
opened = read('save-open-result.json')
require(opened['passed'] and opened['sourceSha256'] == source and opened['actualCardTap'] and opened['dispatchedOutsideApp'] and not opened['physicalDevice'], 'Save actual original-URL opening stale/failed')
bundle = read('save-aab-result.json')
bundle_path = root / bundle['artifact']
require(bundle['exitCode'] == 0 and bundle['sourceSha256'] == source and bundle['sourceUnchanged'] and not bundle['signed'] and not bundle['storeReady'] and bundle_path.is_file() and digest(bundle_path) == bundle['artifactSha256'], 'Save unsigned release AAB missing/stale/hash mismatch')
if bundle['exitCode'] == 0 and bundle_path.is_file():
    with zipfile.ZipFile(bundle_path) as archive:
        require('base/manifest/AndroidManifest.xml' in archive.namelist(), 'AAB manifest missing')
        require(not any(name.startswith('META-INF/') and name.endswith(('.RSA', '.DSA', '.EC', '.SF')) for name in archive.namelist()), 'Expected unsigned AAB; signature found')
for name in ['inbox', 'library-search', 'collections', 'focus', 'settings', 'quick-add']:
    path = evidence / 'screenshots' / f'save-{name}.png'
    require(path.is_file() and path.stat().st_size > 1000, f'Save {name} screenshot missing')
raw = (evidence / 'save-android-instrument-tests.log').read_bytes()
instrument = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
require('OK (5 tests)' in instrument and 'FAILURES' not in instrument, 'Five native queue tests must pass')
permissions = read('save-notifications-results.json')
require(len(permissions) == 2 and {row['permission'] for row in permissions} == {False, True} and all(row['exitCode'] == 0 and row['sourceSha256'] == source and row['sourceUnchanged'] and not row['physicalDevice'] for row in permissions), 'Save notification deny/grant evidence stale/failed')
raw = (evidence / 'save-windows-drop-tests.log').read_bytes()
drop = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
require(drop.count('PASS ') == 9 and 'FAIL ' not in drop, 'Nine Windows native drop parser tests must pass')
browser = read('flutter-browser-tools-results.json')
require(browser['success'] and browser['numFailedTests'] == 0 and browser['numPassedTests'] == 11, 'Eleven RE2/PWA/share worker VM tests must pass')
subprocess.run([sys.executable, str(root / 'tooling/verify-fixtures.py')], check=True)
report = {
    'scope': 'Current seven-app builds and workspace tests; Handy Bookmark emulator integration. Older six-app native integration records remain historical, not rerun here.',
    'sourceSha256': source, 'unitWidgetPassed': tests['totalPassed'],
    'unitWidgetSkipped': tests['totalSkipped'], 'currentSuccessfulBuilds': build_count,
    'validatedUnsignedMsix': msix_count, 'saveAndroidEmulatorIntegration': native['exitCode'] == 0,
    'saveColdWarmShare': share['passed'], 'browserVmTestsPassed': browser['numPassedTests'],
    'saveNotificationsDenyGrant': True, 'windowsNativeDropParserTests': 9,
    'unsignedAndroidReleaseBundle': bundle['exitCode'] == 0, 'saveActualCardOpenDispatch': opened['passed'],
    'externalMetadataFetchVerified': False, 'physicalDeviceVerified': False,
    'iosBuilt': False, 'browserRuntimeVerified': False, 'realStoreTransactionsVerified': False,
    'releaseReady': False, 'errors': errors, 'passed': not errors,
}
(evidence / 'save-checkpoint-audit.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
raise SystemExit(1 if errors else 0)

"""Audit Spend evidence only; other apps' native/build records remain historical."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
evidence = root / 'docs/qa/evidence'
errors = []


def read(name):
    return json.loads((evidence / name).read_text(encoding='utf-8-sig'))


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def log(name):
    raw = (evidence / name).read_bytes()
    return raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')


def require(condition, message):
    if not condition:
        errors.append(message)


source = subprocess.check_output(
    [sys.executable, str(root / 'tooling/flutter-source-fingerprint.py')], text=True,
).strip()
subprocess.run([
    sys.executable, str(root / 'tooling/flutter-test-summary.py'),
    str(evidence / 'spend-workspace-tests.log'),
], check=True)
tests = read('spend-workspace-tests-summary.json')
checks = read('spend-workspace-checks.json')
require(checks['sourceSha256'] == source and checks['sourceUnchanged']
        and checks['testsExitCode'] == 0 and checks['analyzeExitCode'] == 0,
        'Full workspace checks failed or source changed during checks')
require(tests['melosSuccess'] and len(tests['packages']) == 27, 'Full workspace tests incomplete')
require({'handy_spend', 'handy_spend_engine'} <= {p['package'] for p in tests['packages']}, 'Spend tests absent')
counts = {p['package']: p['passed'] for p in tests['packages']}
require(counts.get('handy_spend', 0) >= 16 and counts.get('handy_spend_engine', 0) >= 26,
        'Final crash, planning and bank-fixture regression cases absent')
analysis = log('spend-analyze.log')
require('SUCCESS' in analysis[-250:] and 'FAILED' not in analysis, 'Workspace analysis failed/incomplete')
tooling = read('spend-tooling-checks.json')
require(tooling['typecheckExitCode'] == 0 and tooling['prettierExitCode'] == 0,
        'TypeScript or documentation formatting failed')
for name in ['spend-dart-format.log', 'spend-dart-test-format.log']:
    formatting = log(name)
    require('SUCCESS' in formatting and 'FAILED' not in formatting and 'Changed ' not in formatting,
            f'Dart format incomplete/failed: {name}')
for target in ['apk', 'windows', 'web']:
    rows = [r for r in read(f'builds-{target}.json') if r['app'] == 'spend']
    require(len(rows) == 1, f'{target}: expected exactly one Spend record')
    for row in rows:
        require(row['exitCode'] == 0 and row['sourceUnchanged'] and row['sourceSha256'] == source,
                f'{target}: stale/failed Spend build')
        if target == 'apk':
            path = root / row['artifact']
            require(path.is_file() and digest(path) == row['artifactSha256'], 'APK hash mismatch')
msix = read('spend-msix-result.json')
path = Path(msix['artifact'])
require(msix['sourceSha256'] == source and msix['makeAppxValidated'] and not msix['signed']
        and not msix['installed'] and path.is_file() and digest(path) == msix['sha256'], 'MSIX stale/invalid')
bundle = read('spend-aab-result.json')
path = root / bundle['artifact']
require(bundle['exitCode'] == 0 and bundle['sourceSha256'] == source and bundle['sourceUnchanged']
        and not bundle['signed'] and path.is_file() and digest(path) == bundle['artifactSha256'], 'AAB stale/invalid')
if path.is_file():
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        require('base/manifest/AndroidManifest.xml' in names, 'AAB manifest absent')
        require(not any(n.startswith('META-INF/') and n.endswith(('.RSA', '.DSA', '.EC', '.SF')) for n in names),
                'Expected unsigned AAB')
native = read('spend-android-screenshots-result.json')
require(native['exitCode'] == 0 and native['sourceUnchanged'] and native['sourceSha256'] == source
        and not native['physicalDevice'], 'Android UI integration stale/failed')
for name in ['home', 'transactions', 'reports', 'plan', 'sandbox', 'add-transaction',
             'import-map', 'import-review', 'import-result', 'accounts', 'settings']:
    path = evidence / 'screenshots' / f'spend-{name}.png'
    require(path.is_file() and path.stat().st_size > 1000, f'Screenshot absent: {name}')
review = read('spend-ui-review-result.json')
path = root / review['artifact']
require(review['sourceSha256'] == source and review['pages'] == 11
        and path.is_file() and digest(path) == review['sha256'], 'UI review PDF stale/invalid')
permissions = read('spend-notifications-results.json')
require(len(permissions) == 2 and {r['permission'] for r in permissions} == {False, True}
        and all(r['exitCode'] == 0 and r['sourceUnchanged'] and r['sourceSha256'] == source
                and not r['physicalDevice'] for r in permissions), 'Notification deny/grant stale/failed')
exports = read('spend-export/independent-verification.json')
require(exports['passed'] and len(exports['artifacts']) == 10, 'Independent EN/VI export check incomplete')
for name, row in exports['artifacts'].items():
    path = evidence / 'spend-export' / name
    require(path.is_file() and digest(path) == row['sha256'], f'Export hash mismatch: {name}')
browser = read('flutter-browser-tools-results.json')
require(browser['success'] and browser['numFailedTests'] == 0 and browser['numPassedTests'] == 12,
        'Twelve browser worker/bridge VM tests required')
report = {
    'scope': 'Current Spend builds and Android emulator flows; full workspace unit/widget tests. Other seven apps native/build records are historical.',
    'sourceSha256': source,
    'unitWidgetPassed': tests['totalPassed'], 'unitWidgetSkipped': tests['totalSkipped'],
    'workspacePackages': len(tests['packages']), 'currentSpendBuilds': 3,
    'unsignedAab': True, 'unsignedMsix': True, 'independentExportFiles': 10,
    'uiReviewScreenshots': 11,
    'browserVmTestsPassed': browser['numPassedTests'],
    'androidEmulatorLedgerImportUndo': native['exitCode'] == 0,
    'physicalDeviceVerified': False, 'iosBuilt': False, 'browserRuntimeVerified': False,
    'realStoreTransactionsVerified': False, 'successfulOsDeviceAuthenticationVerified': False,
    'explorerDropVerified': False, 'systemFileProviderVerified': False,
    'delayedRebootNotificationsVerified': False, 'releaseReady': False,
    'errors': errors, 'passed': not errors,
}
(evidence / 'spend-live-workspace-audit.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
raise SystemExit(0 if not errors else 1)

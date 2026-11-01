"""Verify and publish immutable Spend QA evidence without relabeling live edits."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
snapshot = root / '.tooling/spend-qa'
evidence = snapshot / 'docs/qa/evidence'
errors = []


def read(name):
    return json.loads((evidence / name).read_text(encoding='utf-8-sig'))


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def require(condition, message):
    if not condition:
        errors.append(message)


def log(name):
    raw = (evidence / name).read_bytes()
    return raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')


source = subprocess.check_output([sys.executable, str(snapshot / 'tooling/flutter-source-fingerprint.py')], text=True).strip()
require(source == (evidence / 'snapshot-source.txt').read_text(encoding='utf-8-sig').strip(), 'Frozen source changed')
tests_log = log('spend-scoped-tests.log')
packages = [{'package': name, 'passed': int(count), 'skipped': int(skipped or 0)}
            for count, skipped, name in re.findall(r'\+(\d+)(?: ~(\d+))?: All tests passed!\s*\n([a-z_]+): SUCCESS', tests_log)]
require({p['package'] for p in packages} == {'handy_spend', 'handy_spend_engine', 'handy_ui'}
        and len(packages) == 3 and 'FAILED' not in tests_log and 'SUCCESS' in tests_log[-250:], 'Scoped tests failed/incomplete')
analysis = log('spend-scoped-analyze.log')
require('No issues found!' in analysis and 'error -' not in analysis, 'Scoped analyze failed')
for target in ['windows', 'web', 'apk']:
    rows = read(f'builds-{target}.json')
    require(len(rows) == 1 and rows[0]['app'] == 'spend' and rows[0]['exitCode'] == 0
            and rows[0]['sourceUnchanged'] and rows[0]['sourceSha256'] == source, f'Invalid {target} build')
apk = read('builds-apk.json')[0]
path = snapshot / apk['artifact']
require(path.is_file() and digest(path) == apk['artifactSha256'], 'APK hash mismatch')
msix = read('spend-msix-result.json')
path = Path(msix['artifact'])
require(msix['sourceSha256'] == source and msix['makeAppxValidated'] and not msix['signed']
        and not msix['installed'] and path.is_file() and digest(path) == msix['sha256'], 'MSIX mismatch')
aab = read('spend-aab-result.json')
path = snapshot / aab['artifact']
require(aab['exitCode'] == 0 and aab['sourceUnchanged'] and aab['sourceSha256'] == source
        and not aab['signed'] and path.is_file() and digest(path) == aab['artifactSha256'], 'AAB mismatch')
if path.is_file():
    with zipfile.ZipFile(path) as archive:
        require('base/manifest/AndroidManifest.xml' in archive.namelist(), 'AAB manifest absent')
        require(not any(n.startswith('META-INF/') and n.endswith(('.RSA', '.DSA', '.EC', '.SF')) for n in archive.namelist()), 'AAB is signed unexpectedly')
native = read('spend-android-screenshots-result.json')
require(native['exitCode'] == 0 and native['sourceUnchanged'] and native['sourceSha256'] == source
        and not native['physicalDevice'], 'Native capture mismatch')
notifications = read('spend-notifications-results.json')
require(len(notifications) == 2 and {r['permission'] for r in notifications} == {False, True}
        and all(r['exitCode'] == 0 and r['sourceUnchanged'] and r['sourceSha256'] == source
                for r in notifications), 'Notification mismatch')
review = read('spend-ui-review-result.json')
require(review['sourceSha256'] == source and review['pages'] == 11
        and digest(snapshot / review['artifact']) == review['sha256'], 'Review PDF mismatch')
exports = read('spend-export/independent-verification.json')
require(exports['passed'] and len(exports['artifacts']) == 10, 'Export proof incomplete')
for name, row in exports['artifacts'].items():
    require(digest(evidence / 'spend-export' / name) == row['sha256'], f'Export mismatch: {name}')
vm = read('flutter-browser-tools-results.json')
require(vm['success'] and vm['numPassedTests'] == 5 and vm['numFailedTests'] == 0, 'Five scoped worker/bridge checks required')
if errors:
    print(json.dumps({'passed': False, 'errors': errors}, indent=2))
    raise SystemExit(1)
if '--verify-only' in sys.argv:
    candidate = root / 'artifacts/flutter/handy_spend' / f'candidate-{source[:12]}'
    if candidate.exists():
        for filename, original in [('handy-spend-debug.apk', snapshot / apk['artifact']),
                                   ('handy-spend-unsigned.aab', snapshot / aab['artifact']),
                                   ('handy-spend-unsigned.msix', Path(msix['artifact']))]:
            if digest(candidate / filename) != digest(original):
                raise SystemExit(f'Published artifact mismatch: {filename}')
    print(json.dumps({'passed': True, 'scope': 'Frozen Spend candidate only',
                      'sourceSha256': source, 'packages': packages}, indent=2))
    raise SystemExit(0)

published = root / 'docs/qa/evidence' / f'spend-candidate-{source[:12]}'
if published.exists():
    raise SystemExit('Candidate already published; refusing overwrite')
shutil.copytree(evidence, published)
artifacts = root / 'artifacts/flutter/handy_spend' / f'candidate-{source[:12]}'
artifacts.mkdir(parents=True, exist_ok=False)
for filename, original in [('handy-spend-debug.apk', snapshot / apk['artifact']),
                           ('handy-spend-unsigned.aab', snapshot / aab['artifact']),
                           ('handy-spend-unsigned.msix', Path(msix['artifact']))]:
    shutil.copy2(original, artifacts / filename)
shutil.copytree(snapshot / 'apps/handy_spend/build/windows/x64/runner/Release', artifacts / 'windows')
shutil.copytree(snapshot / 'apps/handy_spend/build/web', artifacts / 'web')
baseline = json.loads((root / 'docs/qa/evidence/spend-workspace-tests-summary.json').read_text(encoding='utf-8-sig'))
baseline_checks = json.loads((root / 'docs/qa/evidence/spend-workspace-checks.json').read_text(encoding='utf-8-sig'))
live = subprocess.check_output([sys.executable, str(root / 'tooling/flutter-source-fingerprint.py')], text=True).strip()
report = {
    'scope': 'Frozen Spend candidate and shared UI; live workspace receives concurrent edits. Earlier full-workspace regression is a separate baseline.',
    'snapshotRoot': snapshot.relative_to(root).as_posix(), 'snapshotSourceSha256': source,
    'liveWorkspaceSha256AtPublication': live, 'currentLiveWorkspaceCertified': False,
    'snapshotPackages': packages, 'snapshotTestsPassed': sum(p['passed'] for p in packages),
    'baselineWorkspaceTestsPassed': baseline['totalPassed'], 'baselineWorkspaceTestsSkipped': baseline['totalSkipped'],
    'baselineWorkspaceSourceSha256': baseline_checks['sourceSha256'],
    'baselineWorkspaceTestLogSha256': baseline['logSha256'],
    'candidateBuildsPassed': 3, 'androidEmulatorImportUndoPassed': True,
    'androidNotificationDenyGrantPassed': True, 'scopedWorkerVmTestsPassed': 5,
    'independentExportFiles': 10, 'uiReviewScreenshots': 11,
    'evidenceDirectory': published.relative_to(root).as_posix(),
    'artifactDirectory': artifacts.relative_to(root).as_posix(),
    'unsignedAab': True, 'unsignedMsix': True,
    'physicalDeviceVerified': False, 'iosBuilt': False, 'browserRuntimeVerified': False,
    'realStoreTransactionsVerified': False, 'successfulOsDeviceAuthenticationVerified': False,
    'releaseReady': False, 'errors': [], 'passed': True,
}
(published / 'audit.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
(root / 'docs/qa/evidence/spend-checkpoint-audit.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
shutil.copy2(evidence / 'spend-ui-review.pdf', root / 'docs/qa/evidence/spend-ui-review.pdf')
shutil.copy2(evidence / 'spend-ui-review-result.json', root / 'docs/qa/evidence/spend-ui-review-result.json')
print(json.dumps(report, indent=2))

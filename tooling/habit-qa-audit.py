"""Validate Handy Habit evidence against current source; never certify real stores/devices."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
evidence = root / 'docs/qa/evidence'
def read(path):
    b = path.read_bytes()
    return b.decode('utf-16' if b.startswith(b'\xff\xfe') else 'utf-8-sig').replace('\r\n', '\n')
def data(name):
    return json.loads(read(evidence / name))
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
checks = []
def check(name, ok):
    checks.append({'check': name, 'passed': bool(ok)})
source = subprocess.check_output([sys.executable, str(root/'tooling/flutter-source-fingerprint.py'), '--app', 'habit'], text=True).strip()
log = read(evidence/'habit-other-workspace-tests.log')
rows = [{'package': name, 'passed': int(n), 'skipped': int(k or 0)} for n,k,name in
        re.findall(r'\+(\d+)(?: ~(\d+))?: All tests passed!\s*\n([a-z_]+): SUCCESS', log)]
for name, filename in [('handy_habit', 'habit-app-tests.log'), ('handy_habit_engine', 'habit-engine-tests.log')]:
    result = re.findall(r'\+(\d+)(?: ~(\d+))?: All tests passed!', read(evidence/filename))
    check(filename, len(result) == 1)
    if result:
        n,k = result[-1]
        rows.append({'package':name, 'passed':int(n), 'skipped':int(k or 0)})
workspace = re.findall(r'^  - ((?:apps|packages)/handy_[a-z_]+)$', read(root/'pubspec.yaml'), re.M)
expected = {re.search(r'^name:\s*(\w+)', read(root/p/'pubspec.yaml'), re.M)[1] for p in workspace if (root/p/'test').is_dir()}
check('all workspace test packages', {r['package'] for r in rows} == expected and len(rows) == len(expected) and 'FAILED' not in log and 'Some tests failed' not in log and 'SUCCESS' in log[-250:])
check('Habit analyzer', 'No issues found!' in read(evidence/'habit-analyze.log'))
check('workspace analyzer', 'SUCCESS' in read(evidence/'habit-workspace-analyze.log')[-250:])
check('UI render tests', 'All tests passed!' in read(evidence/'habit-ui-shots.log'))
for target in ['web', 'windows', 'apk']:
    found = [r for r in data(f'builds-{target}.json') if r['app'] == 'habit']
    ok = len(found) == 1 and found[0]['exitCode'] == 0 and found[0]['sourceUnchanged'] and found[0]['sourceSha256'] == source
    check(f'{target} build of current source', ok)
    if ok and target == 'apk':
        r = found[0]
        check('preserved production-entrypoint APK checksum', digest(root/r['artifact']) == r['artifactSha256'])
for filename, hashkey in [('habit-aab-result.json','artifactSha256'), ('habit-msix-result.json','sha256')]:
    r = data(filename)
    ok = r['sourceSha256'] == source and (r.get('exitCode',0) == 0) and r.get('sourceUnchanged',True)
    check(filename, ok)
    if ok:
        check(filename+' artifact checksum', digest(root/r['artifact']) == r[hashkey])
native = data('habit-native-result.json')
native_ok = native['exitCode'] == 0 and native['sourceSha256'] == source and native['sourceUnchanged']
if not native_ok and (evidence/'habit-driver-reconnect-result.json').exists():
    r = data('habit-driver-reconnect-result.json')
    native_ok = (r['exitCode'] == 0 and r['sourceSha256'] == source and r['existingProcessResultsRetrieved']
        and r['logSha256'] == digest(evidence/'habit-driver-reconnect.log') and native['sourceSha256'] == source and native['sourceUnchanged'])
check('actual native driver result', native_ok)
process = data('habit-process-result.json')
check('different-process recovery', process['success'] and process['sourceSha256'] == source and process['sourceUnchanged'] and len(process['phases']) == 2 and process['phases'][0]['process'] != process['phases'][1]['process'])
notifications = data('habit-notifications-results.json')
check('OS denied and granted notification schedules/cancel', len(notifications) == 2 and {r['permission'] for r in notifications} == {False,True} and all(r['exitCode'] == 0 and r['sourceSha256'] == source and r['sourceUnchanged'] for r in notifications))
review = data('habit-ui-review-result.json')
check('review PNG/PDF checksums', review['pdfSha256'] == digest(evidence/'habit-ui-review.pdf') and all(digest(root/r['path']) == r['sha256'] for r in review['captures']))
worker = read(evidence/'habit-pwa-worker.log')
check('PWA worker Node VM (not browser)', '1 passed' in worker and 'failed' not in worker.lower() and (evidence/'habit-pwa-worker.log').stat().st_mtime >= (evidence/'habit-web-build.log').stat().st_mtime)
report = {'sourceSha256':source, 'success':all(r['passed'] for r in checks), 'checks':checks,
          'packages':rows, 'passedTests':sum(r['passed'] for r in rows), 'skippedTests':sum(r['skipped'] for r in rows),
          'uiCaptures':len(review['captures']), 'physicalDeviceVerified':False, 'browserRuntimeVerified':False,
          'iosBuilt':False, 'realStoreVerified':False, 'releaseReady':False}
(evidence/'habit-qa-audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f"{report['passedTests']} host tests, {report['skippedTests']} skipped, {len(rows)}/{len(expected)} packages; candidate evidence valid={report['success']}")
for row in checks:
    if not row['passed']: print('NOT VERIFIED: '+row['check'])
raise SystemExit(0 if report['success'] else 1)

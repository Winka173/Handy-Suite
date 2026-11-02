"""Read actual evidence; never infer device/store coverage from a build."""
from pathlib import Path
import hashlib
import json
import subprocess
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = ROOT / 'docs/qa/evidence'


def read(name):
    return json.loads((EVIDENCE / name).read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


source = subprocess.check_output(
    ['python', str(ROOT / 'tooling/flutter-source-fingerprint.py'), '--app', 'boards'],
    cwd=ROOT, text=True).strip()
checks = {}
for kind, name in {
    'host': 'boards-host-result.json',
    'browserIndexedDb': 'boards-browser-result.json',
    'indexedPerformance': 'boards-performance-result.json',
    'nativeWrite': 'boards-native-write-result.json',
    'nativeRead': 'boards-native-read-result.json',
    'aab': 'boards-aab-result.json',
    'msix': 'boards-msix-result.json',
    'screenshots': 'boards-shots-result.json',
    'pwaWorkerVm': 'boards-pwa-result.json',
}.items():
    record = read(name)
    passed = record.get('passed', record.get('exitCode') == 0)
    if kind == 'msix':
        passed = record.get('makeAppxValidated') is True
    if kind == 'screenshots':
        passed = passed and record.get('allImagesFresh') is True
    if kind == 'indexedPerformance':
        passed = passed and record.get('metricsFresh') is True
    artifact = record.get('artifact')
    valid_artifact = True
    if artifact:
        path = ROOT / artifact
        valid_artifact = path.is_file() and sha(path) == record.get('artifactSha256', record.get('sha256'))
    checks[kind] = {
        'evidence': name,
        'current': bool(passed and record.get('sourceUnchanged', True)
                        and record.get('sourceSha256') == source and valid_artifact),
        'record': record,
    }
for target in ['apk', 'windows', 'web']:
    raw = read(f'builds-{target}.json')
    records = raw if isinstance(raw, list) else [raw]
    record = next(r for r in records if r['app'] == 'boards')
    artifact_ok = True
    if record.get('artifact'):
        artifact_path = ROOT / record['artifact']
        artifact_ok = artifact_path.is_file() and sha(artifact_path) == record.get('artifactSha256')
    checks[target] = {'evidence': f'builds-{target}.json', 'record': record,
                      'current': record['exitCode'] == 0 and record['sourceUnchanged']
                      and record['sourceSha256'] == source and artifact_ok}

checks['pwaWorkerVm']['current'] = (
    checks['pwaWorkerVm']['current'] and checks['web']['current']
    and checks['pwaWorkerVm']['record']['testPattern'] == 'handy_boards worker')
exports = read('boards-independent-exports.json')
checks['independentExports'] = {
    'current': len(exports) == 4 and all(
        (EVIDENCE / 'exports' / r['file']).is_file()
        and (not r.get('sha256') or sha(EVIDENCE / 'exports' / r['file']) == r['sha256'])
        and (r.get('unicodeTextVerified') is True or r.get('textNotFormula') is True)
        for r in exports),
    'evidence': 'boards-independent-exports.json',
    'files': {r['file']: sha(EVIDENCE / 'exports' / r['file']) for r in exports},
}

native = {phase: read(f'boards-native-{phase}-report.json') for phase in ['write', 'read']}
checks['nativeRestart'] = {
    'current': checks['nativeWrite']['current'] and checks['nativeRead']['current']
    and native['write']['pid'] != native['read']['pid']
    and all(r['integrity'] == 'ok' and r['canonicalTasks'] == 2 and r['topLevelTasks'] == 1
            for r in native.values()),
    'reports': native,
}
images = sorted((ROOT / 'review-shots/boards').glob('*.png'))
native_images = sorted((EVIDENCE / 'screenshots').glob('boards-native-*.png'))
report = {
    'generatedAt': datetime.now(timezone.utc).isoformat(),
    'sourceSha256': source,
    'allRecordedChecksCurrent': all(c['current'] for c in checks.values()),
    'uiWebChecksCurrent':all(checks[k]['current'] for k in ['host','web','screenshots','pwaWorkerVm','independentExports']),
    'checks': checks,
    'widgetScreenshots': {str(p.relative_to(ROOT)).replace('\\', '/'): sha(p) for p in images},
    'emulatorScreenshots': {str(p.relative_to(ROOT)).replace('\\', '/'): sha(p) for p in native_images},
    'fullMasterComplete': False,
    'physicalDeviceVerified': False,
    'iosBuilt': False,
    'realBrowserVerified': False,
    'realBrowserStorageVerified': checks['browserIndexedDb']['current'],
    'storeReady': False,
    'limitations': 'docs/HANDY_BOARDS_KNOWN_LIMITATIONS.md',
}
out = EVIDENCE / 'boards-checkpoint.json'
out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'allRecordedChecksCurrent': report['allRecordedChecksCurrent'],
                  'uiWebChecksCurrent':report['uiWebChecksCurrent'],
                  'sourceSha256': source, 'widgetScreenshots': len(images),
                  'emulatorScreenshots': len(native_images)}))
if not report['allRecordedChecksCurrent']:
    raise SystemExit(1)

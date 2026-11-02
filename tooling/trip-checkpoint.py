"""Verify current Trip artifacts against recorded source; never rewrite test outcomes."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'docs/qa/evidence'

def read(name):
    return json.loads((EVIDENCE / name).read_text(encoding='utf-8-sig'))

def log_text(name):
    raw = (EVIDENCE / name).read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff'))
                      else 'utf-8-sig')

source = subprocess.check_output(
    ['python', str(ROOT / 'tooling/flutter-source-fingerprint.py'), '--app', 'trip'],
    cwd=ROOT, text=True).strip()
builds = []
for target in ['apk', 'windows', 'web']:
    rows = read(f'builds-{target}.json')
    rows = rows if isinstance(rows, list) else [rows]
    row, = [r for r in rows if r['app'] == 'trip']
    assert row['exitCode'] == 0 and row['sourceUnchanged']
    assert row['sourceSha256'] == source, (target, 'source changed')
    builds.append(row)
artifacts = []
apk = builds[0]
for path, expected in [
    (apk['artifact'], apk['artifactSha256']),
    (read('trip-aab-result.json')['artifact'], read('trip-aab-result.json')['artifactSha256']),
    (read('trip-msix-result.json')['artifact'], read('trip-msix-result.json')['sha256']),
]:
    file = ROOT / path
    digest = hashlib.sha256(file.read_bytes()).hexdigest()
    assert digest == expected, ('artifact changed', path)
    artifacts.append({'path': file.relative_to(ROOT).as_posix(),
                      'bytes': file.stat().st_size, 'sha256': digest})
for name in ['trip-aab-result.json', 'trip-msix-result.json',
             'trip-native-read-result.json', 'trip-memories-write-result.json']:
    result = read(name)
    assert result['sourceSha256'] == source, (name, 'source mismatch')
    if 'exitCode' in result:
        assert result['exitCode'] == 0 and result['sourceUnchanged'], name
logs = ['trip-engine-tests.log', 'trip-app-tests.log', 'trip-review-shots.log']
for log in logs:
    assert 'All tests passed!' in log_text(log), log
test_counts = {}
for name in ['engine', 'app']:
    matches = re.findall(r'\+(\d+): All tests passed!', log_text(f'trip-{name}-tests.log'))
    assert matches, ('missing test count', name)
    test_counts[name] = int(matches[-1])
for log in ['trip-engine-analyze.log', 'trip-app-analyze.log']:
    assert 'No issues found!' in log_text(log), log
assert len(read('trip-pdf-validation.json')['outputs']) == 13
shots = [p for p in (ROOT / 'review-shots/trip').glob('*.png')
         if p.name.startswith(('phone-', 'narrow-vi-', 'tablet-', 'desktop-', 'dark-'))]
assert len(shots) == 70
checkpoint = {'app': 'trip', 'sourceSha256': source, 'artifacts': artifacts,
              'engineTests': test_counts['engine'], 'appTests': test_counts['app'],
              'responsiveScreenshots': len(shots),
              'independentlyDecodedExports': 13,
              'androidEmulatorP1Pid': read('trip-memories-write-report.json')['pid'],
              'physicalDeviceVerified': False, 'iosBuilt': False,
              'browserRuntimeVerified': False, 'storeReady': False,
              'limits': 'docs/handy_trip/KNOWN_LIMITATIONS.md'}
(EVIDENCE / 'trip-final-checkpoint.json').write_text(
    json.dumps(checkpoint, indent=2), encoding='utf-8')
print(json.dumps(checkpoint, indent=2))

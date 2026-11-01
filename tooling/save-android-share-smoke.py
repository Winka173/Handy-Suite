"""Real ADB cold/warm shares against the dedicated Handy Save QA emulator."""
from pathlib import Path
import hashlib
import json
import shlex
import sqlite3
import subprocess
import time

root = Path(__file__).resolve().parent.parent
device = 'emulator-5558'
package = 'com.example.handysuite.save.flutterpilot'
evidence = root / 'docs/qa/evidence'
folder = evidence / 'save-share-native'
folder.mkdir(exist_ok=True)
def adb(*args, binary=False):
    result = subprocess.check_output(['adb', '-s', device, *args], timeout=30)
    return result if binary else result.decode('utf-8', errors='replace')
def shell(*args):
    return adb('shell', ' '.join(shlex.quote(value) for value in args))

assert 'HandySave_QA_API35' in adb('emu', 'avd', 'name'), 'Dedicated app QA emulator required'
source = subprocess.check_output(['python', str(root / 'tooling/flutter-source-fingerprint.py')], text=True).strip()
builds = json.loads((evidence / 'builds-apk.json').read_text(encoding='utf-8-sig'))
build = next(row for row in builds if row['app'] == 'save')
assert build['sourceSha256'] == source and build['exitCode'] == 0 and build['sourceUnchanged']
apk = root / build['artifact']
assert hashlib.sha256(apk.read_bytes()).hexdigest() == build['artifactSha256']
adb('install', '-r', str(apk))
shell('am', 'force-stop', package)
def share(text, title):
    shell('am', 'start', '-W', '-a', 'android.intent.action.SEND', '-t', 'text/plain',
          '--es', 'android.intent.extra.TEXT', text, '--es', 'android.intent.extra.SUBJECT', title,
          '-n', package + '/com.example.handysuite.save.MainActivity')
    time.sleep(3)
    for _ in range(15):
        shell('uiautomator', 'dump', '/sdcard/handy-save-share.xml')
        xml = adb('shell', 'cat', '/sdcard/handy-save-share.xml')
        if 'Saved to Inbox' in xml or 'Edit details' in xml:
            return xml
        time.sleep(1)
    raise AssertionError('Actual UI did not confirm saving')

prefix = 'https://example.org/handy-save-native-qa/'
cold = share(prefix + 'one\n' + prefix + 'two', 'Handy Save cold QA')
(folder / 'cold.xml').write_text(cold, encoding='utf-8')
(evidence / 'screenshots/save-cold-share.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
pid = shell('pidof', package).strip()
warm = share(prefix + 'three', 'Handy Save warm QA')
assert shell('pidof', package).strip() == pid, 'Warm share must reuse the actual activity process'
(folder / 'warm.xml').write_text(warm, encoding='utf-8')
(evidence / 'screenshots/save-warm-share.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
share(prefix + 'one?utm_source=duplicate', 'Duplicate QA')
shell('am', 'force-stop', package)
# Copy main/WAL together only after this isolated process is stopped. Never read
# arbitrary app data or treat a metadata UI label as evidence of a committed row.
for suffix in ['', '-wal', '-shm']:
    try:
        data = adb('exec-out', 'run-as', package, 'cat', 'files/handy-save.sqlite' + suffix, binary=True)
        (folder / ('library.sqlite' + suffix)).write_bytes(data)
    except subprocess.CalledProcessError:
        if not suffix: raise
database = sqlite3.connect(folder / 'library.sqlite')
try:
    rows = database.execute('SELECT payload FROM bookmarks').fetchall()
    bookmarks = [json.loads(row[0]) for row in rows]
    saved = [b for b in bookmarks if b['originalUrl'].startswith(prefix)]
    assert len(saved) == 3, 'Cold/warm/multiple/duplicate persistence must produce exactly three distinct records'
    assert {b['originalUrl'] for b in saved} == {prefix + 'one', prefix + 'two', prefix + 'three'}
    assert database.execute('PRAGMA quick_check').fetchone()[0] == 'ok'
finally:
    database.close()
pending = shell('run-as', package, 'ls', 'files/share_queue')
assert '.json' not in pending, 'Committed shares must be acknowledged'
shell('am', 'start', '-W', '-n', package + '/com.example.handysuite.save.MainActivity')
time.sleep(3)
report = {'passed': True, 'sourceSha256': source, 'device': device,
          'physicalDevice': False, 'actualShareIntents': 3, 'coldAndWarm': True,
          'warmProcessReused': True, 'multipleUrls': True, 'duplicatePreserved': True,
          'databaseRecordsVerified': 3, 'ackQueueEmpty': True,
          'socialApplicationsInstalledAndVerified': False,
          'artifactSha256': build['artifactSha256']}
(evidence / 'save-native-share-result.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))

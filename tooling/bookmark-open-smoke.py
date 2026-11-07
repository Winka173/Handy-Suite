"""Exercise actual bookmark-card URL dispatch on the isolated Android QA AVD."""
from pathlib import Path
import hashlib
import json
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
evidence = root / 'docs/qa/evidence'
package = 'com.example.handysuite.save.flutterpilot'

def adb(*args, binary=False):
    result = subprocess.check_output(['adb', '-s', 'emulator-5558', *args], timeout=30)
    return result if binary else result.decode('utf-8', errors='replace')

def shell(*args):
    return adb('shell', ' '.join(shlex.quote(a) for a in args))

assert 'HandySave_QA_API35' in adb('emu', 'avd', 'name')
source = subprocess.check_output(['python', str(root / 'tooling/flutter-source-fingerprint.py')], text=True).strip()
build = next(b for b in json.loads((evidence / 'builds-apk.json').read_text(encoding='utf-8-sig')) if b['app'] == 'save')
assert build['sourceSha256'] == source and build['sourceUnchanged'] and build['exitCode'] == 0
artifact = root / build['artifact']
assert hashlib.sha256(artifact.read_bytes()).hexdigest() == build['artifactSha256']
adb('install', '-r', str(artifact))
shell('am', 'force-stop', package)
shell('am', 'start', '-W', '-a', 'android.intent.action.SEND', '-t', 'text/plain',
      '--es', 'android.intent.extra.TEXT', 'https://example.org/handy-save-open-qa',
      '--es', 'android.intent.extra.SUBJECT', 'Handy Bookmark open QA',
      '-n', package + '/com.example.handysuite.save.ShareActivity')
time.sleep(5)
shell('uiautomator', 'dump', '/sdcard/handy-save-open.xml')
xml = adb('shell', 'cat', '/sdcard/handy-save-open.xml')
nodes = [n for n in ET.fromstring(xml).iter('node') if 'Handy Bookmark open QA' in (n.get('text', '') + n.get('content-desc', '')) and n.get('clickable') == 'true']
assert nodes, 'Actual bookmark card must be visible and clickable'
bounds = list(map(int, re.findall(r'\d+', nodes[0].get('bounds'))))
shell('input', 'tap', str((bounds[0]+bounds[2])//2), str((bounds[1]+bounds[3])//2))
time.sleep(4)
activity = shell('dumpsys', 'activity', 'activities')
resumed = '\n'.join(line.strip() for line in activity.splitlines() if 'mResumedActivity' in line or 'topResumedActivity' in line)
assert resumed and package not in resumed, 'Card tap must dispatch outside Handy Bookmark'
database = adb('exec-out', 'run-as', package, 'cat', 'files/handy-save.sqlite', binary=True)
# SQL data is validated separately in the share smoke; do not copy a live WAL pair.
assert database.startswith(b'SQLite format 3'), 'Actual app database must exist'
report = {'passed': True, 'sourceSha256': source, 'device': 'emulator-5558',
          'physicalDevice': False, 'actualCardTap': True, 'dispatchedOutsideApp': True,
          'resumedActivity': resumed, 'websiteLoaded': False, 'installedSocialAppVerified': False}
(evidence / 'save-open-result.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
(evidence / 'screenshots/save-open-system-handler.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
shell('am', 'start', '-W', '-n', package + '/com.example.handysuite.save.MainActivity')
print(json.dumps(report, indent=2))

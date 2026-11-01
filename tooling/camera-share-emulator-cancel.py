"""Use only the named Media test's real emulator camera/share UI; never send files."""
from pathlib import Path
import json
import subprocess
import time
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
log = root / 'docs/qa/evidence/media-camera-share-android-screenshots.log'
actions = []
deadline = time.monotonic() + 300

def adb(*args):
    return subprocess.check_output(['adb', '-s', 'emulator-5556', *args], timeout=15)

def nodes():
    adb('shell', 'uiautomator', 'dump', '/sdcard/handy-camera-share.xml')
    return list(ET.fromstring(adb('shell', 'cat', '/sdcard/handy-camera-share.xml')).iter('node'))

def tap(node):
    values = [int(n) for n in re.findall(r'\d+', node.get('bounds', ''))]
    if len(values) != 4: raise ValueError('Invalid camera button bounds')
    adb('shell', 'input', 'tap', str((values[0]+values[2])//2), str((values[1]+values[3])//2))

while time.monotonic() < deadline and len(actions) < 3:
    raw = log.read_bytes() if log.exists() else b''
    text = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig', errors='replace')
    stage = len(actions)
    marker = ['HANDY_CAMERA_SYSTEM_CANCEL', 'HANDY_CAMERA_SYSTEM_CAPTURE', 'HANDY_SHARE_SYSTEM_DISMISS'][stage]
    if marker not in text:
        time.sleep(.5)
        continue
    try:
        activities = adb('shell', 'dumpsys', 'activity', 'activities').decode('utf-8', errors='replace')
        top = '\n'.join(line for line in activities.splitlines() if 'topResumedActivity' in line or 'mResumedActivity' in line)
        if 'com.example.handysuite.media.flutterpilot' not in activities:
            time.sleep(.5)
            continue
        expected = (any(p in top for p in ['com.android.camera2', 'com.android.camera/', 'com.android.permissioncontroller'])
                    if stage < 2 else any(p in top for p in ['ChooserActivity', 'ResolverActivity']))
        if not expected:
            time.sleep(.5)
            continue
        filename = ['media-camera-system.png', 'media-camera-taking-photo.png', 'media-share-system.png'][stage]
        (root / 'docs/qa/evidence/screenshots' / filename).write_bytes(adb('exec-out', 'screencap', '-p'))
        if stage == 1:
            pressed = False
            confirmed = False
            for _ in range(25):
                camera = [n for n in nodes() if n.get('package') in {'com.android.camera2', 'com.android.camera'} and n.get('enabled') == 'true']
                done = [n for n in camera if any(key in n.get('resource-id','').lower() for key in ['done_button','review_done']) or n.get('content-desc','').lower() in {'done','confirm'}]
                if pressed and done:
                    tap(done[0]); confirmed = True; break
                shutter = [n for n in camera if 'shutter_button' in n.get('resource-id','') or n.get('content-desc','').lower() == 'shutter']
                if not pressed and shutter:
                    tap(shutter[0]); pressed = True
                time.sleep(.5)
            if not confirmed: raise ValueError('Camera shutter/confirmation was not found')
        else:
            # Real Back cancels; no permission grants or recipient selection.
            adb('shell', 'input', 'keyevent', '4')
        if stage == 0:
            for _ in range(8):
                time.sleep(.5)
                current = adb('shell', 'dumpsys', 'activity', 'activities').decode('utf-8', errors='replace')
                resumed = '\n'.join(line for line in current.splitlines() if 'topResumedActivity' in line or 'mResumedActivity' in line)
                if 'com.example.handysuite.media.flutterpilot' in resumed:
                    break
                if any(p in resumed for p in ['com.android.camera2', 'com.android.camera/', 'com.android.permissioncontroller']):
                    adb('shell', 'input', 'keyevent', '4')
        actions.append({'marker': marker, 'activity': top.strip(), 'action': 'camera shutter and confirm' if stage == 1 else 'system Back', 'realSystemUi': True})
        print(json.dumps(actions[-1]), flush=True)
    except (subprocess.SubprocessError, ET.ParseError, ValueError):
        time.sleep(.5)

report = {'device': 'emulator-5556', 'physicalDevice': False, 'complete': len(actions) == 3, 'actions': actions}
(root / 'docs/qa/evidence/camera-share-system-actions.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
raise SystemExit(0 if report['complete'] else 1)

"""Respond only to this integration test's real Android MediaProjection dialogs.

Run alongside flutter-screenshots.ps1 -App media -Scenario capture. This helper
does not grant permissions through appops, manufacture consent intents or bypass
the OS prompt. It clicks Cancel once, then Start now for the two explicit test
captures, scoped to emulator-5556 and the Handy Media system dialog.
"""
from pathlib import Path
import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--device', choices=['emulator-5556', 'emulator-5558'], default='emulator-5556')
device = parser.parse_args().device
log = root / 'docs/qa/evidence/media-capture-android-screenshots.log'
actions = []
markers = ['HANDY_CAPTURE_CONSENT_CANCEL', 'HANDY_CAPTURE_CONSENT_IMAGE', 'HANDY_CAPTURE_CONSENT_VIDEO']
deadline = time.monotonic() + 240

def adb(*arguments):
    return subprocess.check_output(['adb', '-s', device, *arguments], timeout=15).decode('utf-8', errors='replace')

def tap(node):
    bounds = [int(x) for x in re.findall(r'\d+', node.get('bounds', ''))]
    if len(bounds) != 4:
        raise ValueError('Unexpected consent button geometry')
    adb('shell', 'input', 'tap', str((bounds[0] + bounds[2]) // 2), str((bounds[1] + bounds[3]) // 2))

while time.monotonic() < deadline and len(actions) < 3:
    data = log.read_bytes() if log.exists() else b''
    text = data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig', errors='replace')
    stage = len(actions)
    if markers[stage] not in text:
        # Flutter's host log can stop after an ADB disconnect while the same
        # native test VM remains alive. Read only that app PID's test markers.
        try:
            pid = adb('shell', 'pidof', 'com.example.handysuite.media.flutterpilot').strip()
            if pid.isdigit():
                text += adb('logcat', '-d', f'--pid={pid}', '-s', 'flutter:I')
        except subprocess.SubprocessError:
            pass
    if markers[stage] not in text:
        time.sleep(1)
        continue
    try:
        adb('shell', 'uiautomator', 'dump', '/sdcard/handy-capture-consent.xml')
        xml = adb('shell', 'cat', '/sdcard/handy-capture-consent.xml')
        nodes = list(ET.fromstring(xml).iter('node'))
        # Ensure the OS prompt names our own app before interacting.
        if not any('Handy Media' in n.get('text', '') and n.get('package') == 'com.android.systemui' for n in nodes):
            time.sleep(1)
            continue
        if stage > 0:
            # Android 14+ defaults to one-app sharing. Choose the OS's explicit
            # Entire screen option so the test does not remain at an app picker.
            spinners = [n for n in nodes if n.get('class') == 'android.widget.Spinner' and n.get('package') == 'com.android.systemui']
            if spinners and not any('Entire screen' in n.get('text', '') or 'entire screen' in n.get('text', '') for n in nodes):
                tap(spinners[0])
                time.sleep(.5)
                adb('shell', 'uiautomator', 'dump', '/sdcard/handy-capture-consent.xml')
                options = list(ET.fromstring(adb('shell', 'cat', '/sdcard/handy-capture-consent.xml')).iter('node'))
                entire = [n for n in options if n.get('text', '').lower() == 'entire screen' and n.get('package') == 'com.android.systemui']
                if not entire:
                    raise ValueError('The OS entire-screen sharing option was not found')
                tap(entire[0])
                time.sleep(.5)
                continue
        expected = 'android:id/button2' if stage == 0 else 'android:id/button1'
        buttons = [n for n in nodes if n.get('resource-id') == expected and n.get('package') == 'com.android.systemui' and n.get('enabled') == 'true']
        if not buttons:
            time.sleep(1)
            continue
        button = buttons[0]
        tap(button)
        actions.append({'marker': markers[stage], 'button': button.get('text'), 'resourceId': expected, 'realSystemDialog': True})
        print(json.dumps(actions[-1]), flush=True)
        time.sleep(1)
    except (ET.ParseError, subprocess.SubprocessError):
        time.sleep(1)

report = {'device': device, 'physicalDevice': False, 'actions': actions, 'complete': len(actions) == 3}
(root / 'docs/qa/evidence/capture-consent-actions.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
raise SystemExit(0 if report['complete'] else 1)

"""Place one test fixture in the isolated debug app sandbox after its own marker."""
from pathlib import Path
import json
import subprocess
import time

root = Path(__file__).resolve().parent.parent
device = 'emulator-5558'
package = 'com.example.handysuite.media.flutterpilot'
deadline = time.monotonic()+240
while time.monotonic() < deadline:
    try:
        pid = subprocess.check_output(['adb','-s',device,'shell','pidof',package],timeout=8).decode().strip()
        if not pid.isdigit():
            time.sleep(1)
            continue
        log = subprocess.check_output(['adb','-s',device,'logcat','-d',f'--pid={pid}','-s','flutter:I'],timeout=8).decode(errors='replace')
        if 'HANDY_VIDEO_TRANSFORM_FIXTURE' not in log:
            time.sleep(1)
            continue
        data = (root/'test-fixtures/video-transform/h264-aac.mp4').read_bytes()
        subprocess.run(['adb','-s',device,'exec-in','run-as',package,'sh','-c',
                        'cat > files/handy-video-qa-fixture.pending'],input=data,check=True,
                       stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=15)
        subprocess.run(['adb','-s',device,'shell','run-as',package,'mv',
                        'files/handy-video-qa-fixture.pending','files/handy-video-qa-fixture.mp4'],
                       check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=10)
        report = {'device':device,'pid':int(pid),'path':'app-private/files/handy-video-qa-fixture.mp4',
                  'bytes':len(data),'debugSandboxOnly':True,'physicalDevice':False,'passed':True}
        (root/'docs/qa/evidence/video-transform-fixture-delivery.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report))
        break
    except subprocess.SubprocessError:
        time.sleep(1)
else:
    raise SystemExit('The isolated video transform test did not request a fixture in time')

"""Decode actual Android outputs independently; FFmpeg is a QA-only dependency."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import cv2
import imageio_ffmpeg
import numpy as np

root = Path(__file__).resolve().parent.parent
folder = root/'docs/qa/evidence/video-transform'
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
results = {}
images = {}
for name, expected, audio in [('source.mp4',(320,240),True),('muted-rotated.mp4',(180,240),False),('resized-audio.mp4',(240,180),True)]:
    path = folder/name
    data = path.read_bytes()
    assert 32 < len(data) <= 30000000
    metadata = subprocess.run([ffmpeg,'-hide_banner','-i',str(path)],capture_output=True).stderr.decode(errors='replace')
    assert re.search(r'Video:\s*h264',metadata)
    assert bool(re.search(r'Audio:\s*aac',metadata)) == audio
    video = cv2.VideoCapture(str(path))
    count = 0
    while True:
        ok, frame = video.read()
        if not ok: break
        assert (frame.shape[1],frame.shape[0]) == expected
        if count == 0: images[name] = frame
        count += 1
        assert count <= 10000
    video.release()
    assert count >= 10
    if audio:
        pcm = subprocess.check_output([ffmpeg,'-v','error','-i',str(path),'-map','0:a:0','-vn','-ac','1','-ar','8000','-f','f32le','pipe:1'])
        samples = np.frombuffer(pcm,dtype='<f4')
        assert len(samples) > 5000 and np.isfinite(samples).all() and float(np.abs(samples).mean()) > .01
    results[name] = {'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'size':list(expected),'decodedFrames':count,'aacAudio':audio}
source = images['source.mp4']
for name, expected in [('muted-rotated.mp4',cv2.resize(cv2.rotate(source,cv2.ROTATE_90_CLOCKWISE),(180,240))),
                       ('resized-audio.mp4',cv2.resize(source,(240,180)))]:
    error = float(np.abs(images[name].astype(np.float32)-expected.astype(np.float32)).mean())
    assert error < 18, f'{name}: pixel orientation/resize mismatch {error}'
    results[name]['meanPixelErrorAgainstExpectedTransform'] = error
report = {'passed':True,'source':'actual Android Media3 exports','decoder':'independent FFmpeg/OpenCV',
          'physicalDeviceVerified':False,'iosVerified':False,'artifacts':results}
(folder/'independent-video-transform.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))

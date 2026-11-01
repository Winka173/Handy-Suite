"""Independently decode actual emulator MP4/PNG artifacts using local OpenCV.

Use the isolated .tooling/video-proof interpreter; no global Python dependencies
are replaced. This verifies real exported bytes, not native metadata mocks.
"""
from pathlib import Path
import hashlib
import json
import cv2
import numpy

root = Path(__file__).resolve().parent.parent
folder = root / 'docs/qa/evidence/native-capture'
results = {}
for name in ['recording.mp4', 'trimmed.mp4', 'joined.mp4']:
    path = folder / name
    data = path.read_bytes()
    assert 32 < len(data) <= 30000000
    video = cv2.VideoCapture(str(path))
    assert video.isOpened(), f'{name}: decoder could not open MP4'
    metadata_count = int(video.get(cv2.CAP_PROP_FRAME_COUNT))
    width, height = int(video.get(cv2.CAP_PROP_FRAME_WIDTH)), int(video.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = video.get(cv2.CAP_PROP_FPS)
    decoded = 0
    colors = set()
    max_edge_error = 0
    try:
        assert 0 < width * height <= 16000000 and 0 < fps < 240
        while True:
            ok, frame = video.read()
            if not ok:
                break
            assert frame.shape[:2] == (height, width)
            colors.add(tuple(int(x) // 16 for x in frame[height // 3, width // 3]))
            # Fixture backgrounds are uniform at this row. Check the encoded
            # right edge independently of the Android player's texture stride.
            edge_error = int(numpy.abs(frame[height // 3, width - 1].astype(numpy.int16) -
                                       frame[height // 3, width // 3].astype(numpy.int16)).max())
            max_edge_error = max(max_edge_error, edge_error)
            decoded += 1
            assert decoded <= 10000
    finally:
        video.release()
    assert decoded > 0 and decoded == metadata_count, f'{name}: incomplete decoder output'
    assert max_edge_error < 25, f'{name}: unexpected encoded right-edge stripe'
    results[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                     'width': width, 'height': height, 'fps': fps,
                     'decodedFrames': decoded, 'distinctSampledColors': len(colors),
                     'maximumRightEdgeColorError': max_edge_error}

source = results['recording.mp4']
assert source['distinctSampledColors'] >= 2, 'Recording did not capture fixture frame changes'
assert results['trimmed.mp4']['decodedFrames'] <= source['decodedFrames']
assert 1.9 * source['decodedFrames'] <= results['joined.mp4']['decodedFrames'] <= 2 * source['decodedFrames']
for name in ['frame.png', 'screenshot.png']:
    path = folder / name
    data = path.read_bytes()
    image = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    assert image is not None and image.size > 0 and image.shape[0] * image.shape[1] <= 16000000
    results[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                     'width': image.shape[1], 'height': image.shape[0]}
assert (results['frame.png']['width'], results['frame.png']['height']) == (source['width'], source['height'])
report = {'decoder': f'OpenCV {cv2.__version__}', 'numpy': numpy.__version__, 'passed': True,
          'physicalDeviceVerified': False, 'artifacts': results}
(folder / 'independent-video-verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(f'Independent decode passed: {len(results)} actual files; {source["decodedFrames"]} recording frames')

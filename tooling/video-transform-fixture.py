"""Produce a deterministic local H.264/AAC QA fixture, never bundled in the app."""
from pathlib import Path
import hashlib
import json
import subprocess
import imageio_ffmpeg

root = Path(__file__).resolve().parent.parent
folder = root / 'test-fixtures/video-transform'
folder.mkdir(exist_ok=True)
target = folder / 'h264-aac.mp4'
subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-f', 'lavfi', '-i',
                'testsrc2=size=320x240:rate=10:duration=1.5', '-f', 'lavfi', '-i',
                'sine=frequency=440:sample_rate=44100:duration=1.5', '-c:v',
                'libx264', '-bf', '0', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '64k',
                '-shortest', '-map_metadata', '-1', str(target)], check=True,
               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
data = target.read_bytes()
report = {'file': target.name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
          'generator': 'local FFmpeg via isolated imageio-ffmpeg 0.6.0; QA only',
          'video': 'H.264 320x240 10fps color test pattern', 'audio': 'AAC 440Hz sine wave',
          'productionAsset': False}
report['inputSubset'] = 'No B-frames: the existing owned-import remux requires monotonically increasing PTS'
(folder / 'MANIFEST.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report))

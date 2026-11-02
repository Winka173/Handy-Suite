"""Runs each app's guided tour on an Android device and films it.

Usage: python tooling/device-tour.py --device 127.0.0.1:5560 [app ...]

For every app it starts `adb shell screenrecord` in back-to-back segments
(the tool stops at 3 minutes), runs `integration_test/tour_test.dart` on the
device, stops the recording, pulls the segments and joins them into
`device-tours/<app>.mp4` (git-ignored). The test log and pass/fail land next
to it, and `device-tours/index.html` lists every film.

These are emulator or BlueStacks runs unless the device is a real phone;
the result file records the device's model and Android version as reported
by adb, and nothing here claims a physical-device check.
"""
import argparse
import datetime
import html
import json
import os
import pathlib
import shutil
import subprocess
import sys
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'device-tours'
APPS = ['tools', 'dev', 'keep', 'recall', 'bookmark', 'docs', 'media', 'spend', 'habit']
SEGMENT = 170


def adb_path():
    sdk = os.environ.get('ANDROID_HOME') or os.path.join(
        os.environ.get('LOCALAPPDATA', ''), 'Android', 'Sdk')
    exe = os.path.join(sdk, 'platform-tools', 'adb.exe' if os.name == 'nt' else 'adb')
    return exe if os.path.exists(exe) else shutil.which('adb')


def ffmpeg_path():
    try:
        import imageio_ffmpeg  # type: ignore
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return shutil.which('ffmpeg')


class Recorder:
    """Back-to-back screenrecord segments until stopped."""

    def __init__(self, adb, device, name):
        self.adb, self.device, self.name = adb, device, name
        self.segments, self.stop_flag = [], threading.Event()
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.current = None

    def _run(self):
        i = 0
        while not self.stop_flag.is_set():
            remote = f'/sdcard/tour-{self.name}-{i:02d}.mp4'
            self.segments.append(remote)
            self.current = subprocess.Popen(
                [self.adb, '-s', self.device, 'shell', 'screenrecord',
                 '--time-limit', str(SEGMENT), '--bit-rate', '6000000', remote],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.current.wait()
            i += 1

    def start(self):
        self.thread.start()
        time.sleep(1.5)

    def stop(self):
        if not self.thread.is_alive():
            return
        self.stop_flag.set()
        time.sleep(1.5)
        # screenrecord finishes its file cleanly on SIGINT.
        subprocess.run([self.adb, '-s', self.device, 'shell', 'pkill', '-2', 'screenrecord'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.thread.join(timeout=15)
        time.sleep(1)

    def collect(self, folder):
        files = []
        for remote in self.segments:
            local = folder / pathlib.Path(remote).name
            r = subprocess.run([self.adb, '-s', self.device, 'pull', remote, str(local)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run([self.adb, '-s', self.device, 'shell', 'rm', '-f', remote],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if r.returncode == 0 and local.exists() and local.stat().st_size > 1000:
                files.append(local)
        return files


def join(ffmpeg, parts, target):
    if not parts:
        return False
    if len(parts) == 1 or not ffmpeg:
        shutil.copy(parts[0], target)
        return True
    listing = target.with_suffix('.txt')
    listing.write_text(''.join(f"file '{p.as_posix()}'\n" for p in parts), encoding='utf-8')
    r = subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0',
                        '-i', str(listing), '-c', 'copy', str(target)])
    listing.unlink(missing_ok=True)
    return r.returncode == 0


def prop(adb, device, name):
    return subprocess.run([adb, '-s', device, 'shell', 'getprop', name],
                          capture_output=True, text=True).stdout.strip()


def connect(adb, device):
    """Network devices (BlueStacks) drop off when another tool restarts the
    adb server; connect again before each run and wait until it answers."""
    if ':' in device:
        subprocess.run([adb, 'connect', device],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        subprocess.run([adb, '-s', device, 'wait-for-device'], timeout=30,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        pass


def run_test(app, device, adb, log):
    """Runs the tour test, filming only once the app is on screen: the
    build and install before that would be a minute of home screen."""
    rec = Recorder(adb, device, app)
    with open(log, 'w', encoding='utf-8') as out:
        proc = subprocess.Popen(
            ['flutter', 'test', 'integration_test/tour_test.dart', '-d', device],
            cwd=ROOT / 'apps' / f'handy_{app}', stdout=out, stderr=subprocess.STDOUT,
            shell=os.name == 'nt')
        while proc.poll() is None:
            if ': Handy ' in log.read_text(encoding='utf-8', errors='replace'):
                rec.start()
                break
            time.sleep(.3)
        code = proc.wait()
    return code, rec


def tour(app, device, adb, ffmpeg):
    folder = OUT / app
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob('tour-*.mp4'):
        old.unlink()
    log = folder / 'tour.log'
    started = time.time()
    for attempt in range(2):
        connect(adb, device)
        code, rec = run_test(app, device, adb, log)
        lost = 'No devices are connected' in log.read_text(encoding='utf-8', errors='replace')
        if not lost or attempt:
            break
        time.sleep(3)
    rec.stop()
    parts = rec.collect(folder)
    film = folder / f'{app}.mp4'
    joined = join(ffmpeg, parts, film)
    if joined:
        for p in parts:
            if p != film:
                p.unlink(missing_ok=True)
    tail = log.read_text(encoding='utf-8', errors='replace').strip().splitlines()[-1:] or ['']
    result = {
        'app': app,
        'device': device,
        'model': prop(adb, device, 'ro.product.model'),
        'android': prop(adb, device, 'ro.build.version.release'),
        'passed': code == 0,
        'exitCode': code,
        'seconds': round(time.time() - started),
        'film': film.name if joined else None,
        'lastLine': tail[0],
        'finishedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    (folder / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(f"{app}: {'passed' if code == 0 else 'FAILED'} in {result['seconds']} s, film {'ok' if joined else 'missing'}")
    return result


def reinstall(app, device, adb):
    """Puts the normal app back: `flutter test` removes its test build."""
    connect(adb, device)
    cwd = ROOT / 'apps' / f'handy_{app}'
    built = subprocess.run(
        ['flutter', 'build', 'apk', '--debug', '--target-platform', 'android-x64'],
        cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        shell=os.name == 'nt').returncode == 0
    apk = cwd / 'build' / 'app' / 'outputs' / 'flutter-apk' / 'app-debug.apk'
    ok = built and subprocess.run([adb, '-s', device, 'install', '-r', str(apk)],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    print(f"{app}: {'reinstalled' if ok else 'reinstall failed'}")


def index(results):
    rows = []
    for r in results:
        film = f'<video controls preload="metadata" src="{r["app"]}/{r["film"]}"></video>' if r['film'] else '<p>No film.</p>'
        state = 'passed' if r['passed'] else 'failed'
        rows.append(
            f'<section><h2>Handy {html.escape(r["app"].title())} <span class="{state}">{state}</span></h2>'
            f'<p>{html.escape(r["model"])} · Android {html.escape(r["android"])} · {r["seconds"]} s · '
            f'<a href="{r["app"]}/tour.log">log</a></p>{film}</section>')
    (OUT / 'index.html').write_text(
        '<!doctype html><meta charset="utf-8"><title>Device tours</title>'
        '<style>body{font:15px system-ui;margin:24px;max-width:1100px}video{width:100%;max-height:70vh;background:#111}'
        'section{margin-bottom:40px}.passed{color:#15803d}.failed{color:#b91c1c}</style>'
        '<h1>Device tours</h1>' + ''.join(rows), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', required=True)
    parser.add_argument('apps', nargs='*')
    args = parser.parse_args()
    adb, ffmpeg = adb_path(), ffmpeg_path()
    if not adb:
        sys.exit('adb not found')
    OUT.mkdir(exist_ok=True)
    results = []
    for app in args.apps or APPS:
        results.append(tour(app, args.device, adb, ffmpeg))
        reinstall(app, args.device, adb)
    # Keep earlier results for apps not run this time.
    done = {r['app'] for r in results}
    for app in APPS:
        f = OUT / app / 'result.json'
        if app not in done and f.exists():
            results.append(json.loads(f.read_text(encoding='utf-8')))
    results.sort(key=lambda r: APPS.index(r['app']) if r['app'] in APPS else 99)
    index(results)
    print(f'index: {OUT / "index.html"}')


if __name__ == '__main__':
    main()

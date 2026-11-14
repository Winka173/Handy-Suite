"""Drive the app on a device by what the screen says (uiautomator), for the
final test (docs/HANDY_BOOKMARK_FINAL_TEST.md).

  python tooling/bookmark-final/ui.py labels                 # what is on screen
  python tooling/bookmark-final/ui.py tap "Skip"             # tap by label (substring)
  python tooling/bookmark-final/ui.py tap "Skip" --exact
  python tooling/bookmark-final/ui.py type "https://..."     # into the focused field
  python tooling/bookmark-final/ui.py shot F-A1              # docs/qa/evidence/bookmark-final/F-A1.png
  python tooling/bookmark-final/ui.py swipe up|down
  python tooling/bookmark-final/ui.py back|home

Device: env HB_DEVICE (default emulator-5554).
"""
import html
import os
import re
import subprocess
import sys
import time

DEVICE = os.environ.get("HB_DEVICE", "emulator-5554")
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EVIDENCE = os.path.join(ROOT, "docs", "qa", "evidence", "bookmark-final")


def adb(*args, binary=False):
    out = subprocess.run(["adb", "-s", DEVICE, *args], capture_output=True)
    return out.stdout if binary else out.stdout.decode("utf-8", "replace")


def nodes():
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    xml = adb("shell", "cat", "/sdcard/ui.xml")
    found = []
    for m in re.finditer(r"<node [^>]*>", xml):
        n = m.group(0)
        label = ""
        for attr in ("content-desc", "text"):
            a = re.search(attr + r'="([^"]*)"', n)
            if a and a.group(1):
                label = html.unescape(a.group(1))
                break
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
        if label and b:
            x1, y1, x2, y2 = map(int, b.groups())
            found.append((label, (x1 + x2) // 2, (y1 + y2) // 2, "clickable=\"true\"" in n))
    return found


def tap(label, exact=False):
    for _ in range(3):
        for text, x, y, _ in nodes():
            t = text.replace("\n", " ")
            if (t == label) if exact else (label.lower() in t.lower()):
                adb("shell", "input", "tap", str(x), str(y))
                time.sleep(1.2)
                print(f"tapped '{t[:60]}' at {x},{y}")
                return True
        time.sleep(1)
    print(f"NOT FOUND: {label}")
    return False


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "labels"
    arg = sys.argv[2] if len(sys.argv) > 2 else ""
    if cmd == "labels":
        for text, x, y, click in nodes():
            print(("* " if click else "  ") + text.replace("\n", " | ")[:110], f"@{x},{y}")
    elif cmd == "tap":
        sys.exit(0 if tap(arg, "--exact" in sys.argv) else 1)
    elif cmd == "type":
        adb("shell", "input", "text", arg.replace(" ", "%s").replace("&", "\\&").replace("?", "\\?"))
    elif cmd == "shot":
        os.makedirs(EVIDENCE, exist_ok=True)
        path = os.path.join(EVIDENCE, arg + ".png")
        with open(path, "wb") as f:
            f.write(adb("exec-out", "screencap", "-p", binary=True))
        print(path)
    elif cmd == "swipe":
        a, b = ("1700", "500") if arg == "up" else ("500", "1700")
        adb("shell", "input", "swipe", "540", a, "540", b, "350")
        time.sleep(1)
    elif cmd in ("back", "home"):
        adb("shell", "input", "keyevent", "KEYCODE_BACK" if cmd == "back" else "KEYCODE_HOME")
        time.sleep(1)


if __name__ == "__main__":
    main()

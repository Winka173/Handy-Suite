"""Install the source apps for the final share test from Play Store on the
emulator (a Google account must already be signed in). Opens each app's
store page and taps Install; never signs in to anything.

  python -X utf8 tooling/bookmark-final/install_apps.py
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import ui  # noqa: E402

APPS = {
    "Facebook": "com.facebook.katana",
    "Instagram": "com.instagram.android",
    "TikTok": "com.ss.android.ugc.trill",
    "Threads": "com.instagram.barcelona",
    "X": "com.twitter.android",
    "Reddit": "com.reddit.frontpage",
    "Shopee": "com.shopee.vn",
    "ShopeeFood": "com.deliverynow",
    "Grab": "com.grabtaxi.passenger",
    "Lazada": "com.lazada.android",
    "Tiki": "vn.tiki.app.tikiandroid",
    "Pinterest": "com.pinterest",
    "Spotify": "com.spotify.music",
    "Coc Coc": "com.coccoc.trinhduyet",
    "Firefox": "org.mozilla.firefox",
    "Edge": "com.microsoft.emmx",
    "Opera": "com.opera.browser",
}


def installed(pkg):
    return pkg in ui.adb("shell", "pm", "list", "packages", pkg)


for name, pkg in APPS.items():
    if installed(pkg):
        print(f"{name}: already installed")
        continue
    ui.adb("shell", "am", "start", "-a", "android.intent.action.VIEW",
           "-d", f"market://details?id={pkg}", "-p", "com.android.vending")
    time.sleep(6)
    if not (ui.tap("Install", exact=True) or ui.tap("Cài đặt", exact=True)):
        print(f"{name}: no Install button (region or account?)")
        continue
    print(f"{name}: installing…")
    for _ in range(60):  # up to 5 minutes each
        time.sleep(5)
        if installed(pkg):
            print(f"{name}: installed")
            break
    else:
        print(f"{name}: still downloading, moving on")
ui.adb("shell", "input", "keyevent", "KEYCODE_HOME")

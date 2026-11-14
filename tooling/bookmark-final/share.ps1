<#
  Handy Bookmark final test: send what each app sends when you tap Share,
  into the installed app, one share at a time (docs/HANDY_BOOKMARK_FINAL_TEST.md, C).
  Each share opens the share sheet; pick or name the collection on the device,
  then press Enter here for the next one.

  ./tooling/bookmark-final/share.ps1 -Device emulator-5554
  ./tooling/bookmark-final/share.ps1 -Device emulator-5554 -Only tiktok
#>
param(
  [string]$Device = "emulator-5554",
  [string]$Package = "com.apps.winka.handybookmark",
  [string]$Only = "",
  [switch]$NoWait
)

# Only addresses that were confirmed to exist (2026-11-14); the text around
# them follows each app's own share format.
$shares = @(
  @{ id = "youtube";       text = "https://youtu.be/jNQXAC9IVRw?si=FinalTest01" },
  @{ id = "youtube";       text = "https://youtu.be/dQw4w9WgXcQ?si=FinalTest02" },
  @{ id = "shorts";        text = "https://youtube.com/shorts/8xkEICotpOM?si=FinalTest03" },
  @{ id = "tiktok";        text = "Check out TikTok's video! #TikTok https://www.tiktok.com/@tiktok/video/6724421900094737670?_r=1&_t=FinalTest" },
  @{ id = "tiktok";        text = "https://www.tiktok.com/@tiktok_australia/video/7356179593268579602?is_from_webapp=1&sender_device=pc" },
  @{ id = "instagram";     text = "https://www.instagram.com/instagram?igsh=RmluYWxUZXN0" },
  @{ id = "facebook";      text = "https://www.facebook.com/Meta?mibextid=FinalTest" },
  @{ id = "facebookreel";  text = "https://www.facebook.com/Meta/reels/" },
  @{ id = "x";             text = "https://x.com/X?s=21" },
  @{ id = "threads";       text = "https://www.threads.net/@zuck" },
  @{ id = "reddit";        text = "https://www.reddit.com/r/FlutterDev/?share_id=FinalTest" },
  @{ id = "web";           text = "Hà Nội – Wikipedia tiếng Việt https://vi.wikipedia.org/wiki/H%C3%A0_N%E1%BB%99i" },
  @{ id = "multi";         text = "Ba link một lần: https://vnexpress.net/ https://tuoitre.vn/ https://github.com/flutter/flutter" },
  @{ id = "nolink";        text = "Chỉ có chữ, không có link nào" },
  @{ id = "duplicate";     text = "https://www.youtube.com/watch?v=jNQXAC9IVRw" }
)

$component = "$Package/com.example.handysuite.save.ShareActivity"
foreach ($s in $shares) {
  if ($Only -and $s.id -ne $Only) { continue }
  # Single quotes for the device shell; a quote inside the text is escaped.
  $text = $s.text.Replace("'", "'\''")
  Write-Host "== $($s.id): $($s.text)"
  adb -s $Device shell "am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT '$text' -n $component" | Out-Null
  if (-not $NoWait) { Read-Host "Pick a collection on the device, then press Enter" | Out-Null }
  else { Start-Sleep -Seconds 6 }
}

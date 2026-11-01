param([ValidateSet('keep','recall')][string]$App)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
$mutex=Enter-HandyAndroidBuild
$adb=Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$package="com.example.handysuite.$App.flutterpilot"
$apk=Join-Path $root "apps/handy_$App/build/app/outputs/flutter-apk/app-debug.apk"
if (!(Test-Path -LiteralPath $apk)) { throw 'Build the pilot Android APK before running notification integration.' }
& $adb -s emulator-5556 install -r -t $apk | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not install the isolated pilot APK.' }
$dump=& $adb -s emulator-5556 shell dumpsys package $package
$original=($dump | Select-String 'android.permission.POST_NOTIFICATIONS: granted=true').Count -gt 0
$results=@()
Push-Location (Join-Path $root "apps/handy_$App")
try {
  foreach($allowed in @($false,$true)) {
    # Flutter drive removes its test package on exit; restore it before each case.
    & $adb -s emulator-5556 install -r -t $apk | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not reinstall the isolated pilot APK.' }
    $action=if($allowed){'grant'}else{'revoke'}
    & $adb -s emulator-5556 shell pm $action $package android.permission.POST_NOTIFICATIONS
    if($LASTEXITCODE -ne 0){throw 'Could not set notification permission on the isolated pilot package.'}
    $flag=$allowed.ToString().ToLowerInvariant()
    $ErrorActionPreference='Continue'
    & flutter drive --no-pub --driver=test_driver/screenshots.dart --target=integration_test/notifications_test.dart -d emulator-5556 "--dart-define=EXPECTED_NOTIFICATIONS=$flag" *> (Join-Path $root "docs/qa/evidence/$App-notification-$flag.log")
    $code=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    $results+=[pscustomobject]@{app=$App;permission=$allowed;exitCode=$code;device='emulator-5556';physicalDevice=$false;scheduledDeliveryTimingVerified=$false}
  }
} finally {
  $restore=if($original){'grant'}else{'revoke'}
  $installed = & $adb -s emulator-5556 shell pm path $package
  if ($installed -match '^package:') {
    & $adb -s emulator-5556 shell pm $restore $package android.permission.POST_NOTIFICATIONS
  }
  Pop-Location
  $mutex.ReleaseMutex();$mutex.Dispose()
  ConvertTo-Json -InputObject $results -Depth 4 | Set-Content -LiteralPath (Join-Path $root "docs/qa/evidence/$App-notifications-results.json") -Encoding utf8
}
$results | Format-Table
if($results.Count -ne 2 -or $results.Where({$_.exitCode -ne 0}).Count){exit 1}

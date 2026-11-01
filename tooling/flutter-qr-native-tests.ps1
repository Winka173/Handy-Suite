$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
$mutex=Enter-HandyAndroidBuild
$adb=Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$package='com.example.handysuite.tools.flutterpilot'
$apk=Join-Path $root 'artifacts/flutter/handy_tools/android/handy-tools-pilot-debug.apk'
Push-Location (Join-Path $root 'apps/handy_tools')
try {
  & $adb -s emulator-5556 install -r -t $apk | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Could not install isolated pilot APK'}
  & $adb -s emulator-5556 shell pm revoke $package android.permission.CAMERA
  if($LASTEXITCODE -ne 0){throw 'Build current Tools APK with the camera permission first'}
  & $adb -s emulator-5556 shell pm set-permission-flags $package android.permission.CAMERA user-set user-fixed
  if($LASTEXITCODE -ne 0){throw 'Could not configure deterministic denied-camera test'}
  $ErrorActionPreference='Continue'
  & flutter drive --no-pub --driver=test_driver/screenshots.dart --target=integration_test/qr_native_test.dart -d emulator-5556 --dart-define=DENIED_QR_CAMERA=true --dart-define=HANDY_SCREENSHOTS=true *> (Join-Path $root 'docs/qa/evidence/tools-qr-native.log')
  $code=$LASTEXITCODE
  $ErrorActionPreference='Stop'
  [pscustomobject]@{app='tools';exitCode=$code;device='emulator-5556';physicalDevice=$false;cameraPermissionDeniedTest=$true;bundledImageDecoderTest=$true;opticalCameraScanVerified=$false;finishedAt=(Get-Date).ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'docs/qa/evidence/tools-qr-native-result.json') -Encoding utf8
} finally {
  # Flutter drive removes the isolated test package. Clear flags if it remains.
  $installed=& $adb -s emulator-5556 shell pm path $package
  if($installed -match '^package:') { & $adb -s emulator-5556 shell pm clear-permission-flags $package android.permission.CAMERA user-set user-fixed }
  Pop-Location
  $mutex.ReleaseMutex();$mutex.Dispose()
}
exit $code

param([string]$Device='emulator-5570',[ValidateSet('write','read')][string]$Phase='write',[ValidateSet('native','share','permissions','memories')][string]$Scenario='native')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$avd=((& adb -s $Device shell getprop ro.boot.qemu.avd_name) -join '').Trim()
if ($avd -ne 'HandyTrip_QA_API35') { throw 'Dedicated Handy Trip QA emulator required.' }
. (Join-Path $PSScriptRoot 'flutter-android-lock.ps1')
. (Join-Path $PSScriptRoot 'trip-driver-recovery.ps1')
$mutex=Enter-HandyAndroidBuild
try {
  $before=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') --app trip).Trim()
  Push-Location (Join-Path $root 'apps/handy_trip')
  try {
    $ErrorActionPreference='Continue'
    # A release build omits integration_test from the generated Java registrant.
    # Let pub regenerate debug plugin registration before this instrumented build.
    & flutter drive --keep-app-running --no-dds --no-start-paused --timeout=240 "--dart-define=TRIP_QA_PHASE=$Phase" --driver=test_driver/screenshots.dart --target=integration_test/$Scenario`_test.dart -d $Device *> (Join-Path $root "docs/qa/evidence/trip-$Scenario-$Phase.log")
    $code=$LASTEXITCODE
    $ErrorActionPreference='Stop'
  } finally { Pop-Location }
  $transportCode=$code
  $code=Complete-HandyTripDriver -Name "$Scenario-$Phase" -Log (Join-Path $root "docs/qa/evidence/trip-$Scenario-$Phase.log") -Code $code -Source $before -Device $Device
  $after=(& python (Join-Path $root 'tooling/flutter-source-fingerprint.py') --app trip).Trim()
  [pscustomobject]@{app='trip';phase=$Phase;exitCode=$code;originalTransportExitCode=$transportCode;sourceSha256=$before;sourceUnchanged=($before -eq $after);device=$Device;avd=$avd;physicalDevice=$false} | ConvertTo-Json | Set-Content (Join-Path $root "docs/qa/evidence/trip-$Scenario-$Phase-result.json") -Encoding utf8
  if ($code -eq 0) { Copy-Item -LiteralPath (Join-Path $root 'docs/qa/evidence/trip-native-report.json') -Destination (Join-Path $root "docs/qa/evidence/trip-$Scenario-$Phase-report.json") -Force }
  if ($code -ne 0 -or $before -ne $after) { exit 1 }
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
